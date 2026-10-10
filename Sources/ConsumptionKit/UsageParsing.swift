import Foundation

public enum UsageParseError: Error, Equatable {
    case invalidPayload(String)
}

/// Parses `GET https://api.anthropic.com/api/oauth/usage` (the endpoint behind Claude Code's `/usage`).
public enum ClaudeUsageParser {
    struct Response: Decodable {
        struct Bucket: Decodable {
            let utilization: Double?
            let resets_at: String?
        }

        let five_hour: Bucket?
        let seven_day: Bucket?
    }

    public static func parse(_ data: Data, plan: String?, now: Date) throws -> ProviderUsage {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw UsageParseError.invalidPayload("Claude usage: \(error)")
        }
        var windows: [UsageWindow] = []
        if let bucket = response.five_hour {
            windows.append(window(.session, bucket))
        }
        if let bucket = response.seven_day {
            windows.append(window(.weekly, bucket))
        }
        guard !windows.isEmpty else { throw UsageParseError.invalidPayload("Claude usage: no windows") }
        return ProviderUsage(provider: .claude, plan: plan, windows: windows, fetchedAt: now)
    }

    private static func window(_ kind: WindowKind, _ bucket: Response.Bucket) -> UsageWindow {
        UsageWindow(kind: kind, usedPercent: bucket.utilization ?? 0, resetsAt: bucket.resets_at.flatMap(parseISODate))
    }

    static func parseISODate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

/// Parses `GET https://chatgpt.com/backend-api/wham/usage` (the endpoint behind Codex's `/status`).
public enum CodexUsageParser {
    struct Response: Decodable {
        struct RateLimit: Decodable {
            let primary_window: Window?
            let secondary_window: Window?
        }

        struct Window: Decodable {
            let used_percent: Double
            let limit_window_seconds: Double?
            let reset_at: Double?
            let reset_after_seconds: Double?
        }

        struct SpendLimit: Decodable {
            let used_percent: Double
            let reset_at: Double?
            let reset_after_seconds: Double?
        }

        struct SpendControl: Decodable {
            let individual_limit: SpendLimit?
        }

        let plan_type: String?
        let rate_limit: RateLimit?
        let spend_control: SpendControl?
    }

    public static func parse(_ data: Data, now: Date) throws -> ProviderUsage {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw UsageParseError.invalidPayload("Codex usage: \(error)")
        }
        let raw = [response.rate_limit?.primary_window, response.rate_limit?.secondary_window].compactMap(\.self)
        if raw.isEmpty, let limit = response.spend_control?.individual_limit {
            let resetsAt =
                limit.reset_at.map { Date(timeIntervalSince1970: $0) }
                ?? limit.reset_after_seconds.map { now.addingTimeInterval($0) }
            let window = UsageWindow(kind: .monthly, usedPercent: limit.used_percent, resetsAt: resetsAt)
            return ProviderUsage(provider: .codex, plan: response.plan_type, windows: [window], fetchedAt: now)
        }
        guard !raw.isEmpty else { throw UsageParseError.invalidPayload("Codex usage: no windows") }
        let windows = raw.map { window in
            let length = window.limit_window_seconds ?? WindowKind.weekly.defaultLength
            let resetsAt =
                window.reset_at.map { Date(timeIntervalSince1970: $0) }
                ?? window.reset_after_seconds.map { now.addingTimeInterval($0) }
            return UsageWindow(
                kind: WindowKind(length: length), usedPercent: window.used_percent,
                resetsAt: resetsAt, length: length)
        }
        return ProviderUsage(provider: .codex, plan: response.plan_type, windows: windows, fetchedAt: now)
    }
}
