import Foundation

public struct UsageAlert: Sendable, Equatable {
    public enum Kind: String, Sendable { case overPace, nearlyOut, reset, morningSummary }

    /// Stable id: the same condition never alerts twice.
    public var id: String
    public var kind: Kind
    public var title: String
    public var body: String
}

/// What has already been notified, persisted between launches.
public struct AlertState: Codable, Sendable, Equatable {
    public var sentIDs: [String] = []
    /// Last seen reset time and usage per `provider.window`.
    public var lastResetAt: [String: Date] = [:]
    public var lastUsed: [String: Double] = [:]
    public var lastSummaryDay: Day?

    public init() {}
}

/// Pure decision logic for notifications; the app only delivers what this returns.
public struct AlertPlanner: Sendable {
    public var nearlyOutThreshold: Double = 10
    public var morningHour: Int = 8
    /// Session-window resets only notify when the previous window was at least this full.
    public var sessionResetMinimumUsed: Double = 50

    /// Reset times closer than this are the same window.
    private static let resetTolerance: TimeInterval = 300

    public init() {}

    public func plan(
        usages: [ProviderUsage], calendar: WorkCalendar, now: Date,
        state: inout AlertState
    ) -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        let today = Day(now, calendar: calendar.calendar)

        for usage in usages {
            for window in usage.windows {
                alerts += windowAlerts(usage.provider, window, calendar: calendar, now: now, state: &state)
            }
        }

        if calendar.isWorkDay(now), calendar.calendar.component(.hour, from: now) >= morningHour,
            state.lastSummaryDay != today, !usages.isEmpty
        {
            state.lastSummaryDay = today
            alerts.append(
                UsageAlert(
                    id: "summary.\(today)", kind: .morningSummary,
                    title: "Today's AI budget",
                    body: summary(usages: usages, calendar: calendar, now: now)))
        }

        let fresh = alerts.filter { !state.sentIDs.contains($0.id) }
        state.sentIDs = Array((state.sentIDs + fresh.map(\.id)).suffix(200))
        return fresh
    }

    private func windowAlerts(
        _ provider: Provider, _ window: UsageWindow, calendar: WorkCalendar, now: Date, state: inout AlertState
    ) -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        let key = "\(provider.rawValue).\(window.kind.rawValue)"
        let label = "\(provider.displayName) \(window.kind.displayName.lowercased())"
        // A window is identified by the first reset time seen for it: the API may report it a few seconds
        // differently each time (or it is derived from "seconds left"), and that must not look like a new
        // window, which would repeat an alert already sent.
        let canonical = window.resetsAt.map { reset -> Date in
            guard let previous = state.lastResetAt[key], abs(reset.timeIntervalSince(previous)) <= Self.resetTolerance
            else { return reset }
            return previous
        }
        let stamp = canonical.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "none"

        if let previous = state.lastResetAt[key], let reset = window.resetsAt,
            reset.timeIntervalSince(previous) > Self.resetTolerance
        {
            let wasUsed = state.lastUsed[key] ?? 0
            if window.kind == .weekly || wasUsed >= sessionResetMinimumUsed {
                alerts.append(
                    UsageAlert(
                        id: "reset.\(key).\(stamp)", kind: .reset,
                        title: "\(label) limit reset",
                        body: "\(format(window.remainingPercent)) available again."))
            }
        }
        if let canonical { state.lastResetAt[key] = canonical }
        state.lastUsed[key] = window.usedPercent

        if window.remainingPercent < nearlyOutThreshold {
            alerts.append(
                UsageAlert(
                    id: "low.\(key).\(stamp)", kind: .nearlyOut,
                    title: "\(label) limit almost used",
                    body: "Only \(format(window.remainingPercent)) left\(resetSuffix(window))."))
        }

        if window.kind == .weekly, calendar.isWorkDay(now),
            let pace = WindowPace.compute(window: window, calendar: calendar, now: now), pace.isOverPace
        {
            let today = Day(now, calendar: calendar.calendar)
            alerts.append(
                UsageAlert(
                    id: "pace.\(key).\(today)", kind: .overPace,
                    title: "\(provider.displayName) is ahead of pace",
                    body: "Used \(format(pace.usedPercent)) of the week; the even pace allows "
                        + "\(format(pace.targetUsedByEndOfToday)) by tonight. "
                        + "\(format(pace.todayShare))/day left over \(pace.workDaysLeft) days."
                ))
        }
        return alerts
    }

    func summary(usages: [ProviderUsage], calendar: WorkCalendar, now: Date) -> String {
        usages.map { usage in
            if usage.weekly == nil, let monthly = usage.monthly {
                return "\(usage.provider.displayName): \(format(monthly.remainingPercent)) of monthly limit left"
            }
            guard let weekly = usage.weekly else { return "\(usage.provider.displayName): no weekly data" }
            var line = "\(usage.provider.displayName): \(format(weekly.remainingPercent)) of week left"
            if let pace = WindowPace.compute(window: weekly, calendar: calendar, now: now) {
                line += ", \(format(pace.todayShare)) today"
            }
            return line
        }.joined(separator: " · ")
    }

    private func resetSuffix(_ window: UsageWindow) -> String {
        guard let reset = window.resetsAt else { return "" }
        return ", resets \(reset.formatted(.relative(presentation: .named)))"
    }
}

func format(_ percent: Double) -> String {
    percent < 10 && percent.rounded() != percent
        ? String(format: "%.1f%%", percent)
        : String(format: "%.0f%%", percent)
}
