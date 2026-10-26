import Foundation

public enum UsageParseError: Error, Equatable {
    case invalidPayload(String)
}

/// A monthly spend limit, as long as the calendar month that ends at `resetsAt` (so pacing counts
/// the right work days).
func monthlyWindow(usedPercent: Double, resetsAt: Date?) -> UsageWindow {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    let length = resetsAt.flatMap { reset in
        calendar.date(byAdding: .month, value: -1, to: reset).map { reset.timeIntervalSince($0) }
    }
    return UsageWindow(kind: .monthly, usedPercent: usedPercent, resetsAt: resetsAt, length: length)
}

/// Parses `GET https://api.anthropic.com/api/oauth/usage` (the endpoint behind Claude Code's `/usage`).
public enum ClaudeUsageParser {
    struct Response: Decodable {
        struct Bucket: Decodable {
            let utilization: Double?
            let resets_at: String?
        }

        struct ExtraUsage: Decodable {
            let utilization: Double?
            let used_credits: Double?
            let monthly_limit: Double?
            let decimal_places: Int?
            let currency: String?
        }

        let five_hour: Bucket?
        let seven_day: Bucket?
        let extra_usage: ExtraUsage?
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
        if windows.isEmpty, let used = response.extra_usage?.utilization {
            let window = monthlyWindow(usedPercent: used, resetsAt: nextMonthStartUTC(after: now))
            return ProviderUsage(
                provider: .claude, plan: plan, windows: [window], fetchedAt: now,
                spend: response.extra_usage.flatMap(spendReading))
        }
        guard !windows.isEmpty else { throw UsageParseError.invalidPayload("Claude usage: no windows") }
        return ProviderUsage(provider: .claude, plan: plan, windows: windows, fetchedAt: now)
    }

    /// Amounts are in minor units (cents); only USD is understood.
    private static func spendReading(_ extra: Response.ExtraUsage) -> SpendReading? {
        guard extra.currency == "USD", let used = extra.used_credits, let limit = extra.monthly_limit else {
            return nil
        }
        let scale = pow(10, Double(extra.decimal_places ?? 2))
        return SpendReading(used: used / scale, limit: limit / scale, unit: .usd)
    }

    /// The payload carries no reset date for the monthly spend limit; it resets on the 1st, UTC.
    static func nextMonthStartUTC(after date: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let start = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
        return calendar.date(byAdding: .month, value: 1, to: start)
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
            let limit: String?
            let used: String?
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
            let window = monthlyWindow(usedPercent: limit.used_percent, resetsAt: resetsAt)
            var spend: SpendReading?
            if let used = limit.used.flatMap(Double.init), let cap = limit.limit.flatMap(Double.init) {
                spend = SpendReading(used: used, limit: cap, unit: .credits)
            }
            return ProviderUsage(
                provider: .codex, plan: response.plan_type, windows: [window], fetchedAt: now, spend: spend)
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
