import Foundation

/// How a window's remaining quota spreads over the work days left before it resets.
///
/// A window covers the calendar days `[start day, reset day)`: the reset day belongs to the next window.
public struct WindowPace: Sendable, Equatable {
    public var remainingPercent: Double
    /// Work days in the whole window.
    public var totalWorkDays: Int
    /// Work days before today.
    public var elapsedWorkDays: Int
    /// Work days from today (inclusive) until the reset day.
    public var workDaysLeft: Int
    /// Remaining quota divided by the work days left (all of it when none are left).
    public var todayShare: Double
    /// How much of the window should be used by the end of today at an even pace.
    public var targetUsedByEndOfToday: Double
    public var usedPercent: Double

    public var isOverPace: Bool { usedPercent > targetUsedByEndOfToday + 0.5 }

    public static func compute(window: UsageWindow, calendar: WorkCalendar, now: Date) -> Self? {
        guard let reset = window.resetsAt else { return nil }
        let start = reset.addingTimeInterval(-window.length)
        let elapsed = calendar.workDays(from: start, to: now)
        let left = calendar.workDays(from: now, to: reset)
        let total = elapsed + left
        let countsToday = calendar.isWorkDay(now) && left > 0 ? 1 : 0
        let target = total == 0 ? 100 : 100 * Double(elapsed + countsToday) / Double(total)
        return Self(
            remainingPercent: window.remainingPercent,
            totalWorkDays: total,
            elapsedWorkDays: elapsed,
            workDaysLeft: left,
            todayShare: window.remainingPercent / Double(max(left, 1)),
            targetUsedByEndOfToday: target,
            usedPercent: window.usedPercent
        )
    }
}

/// The month view: work days in the calendar month and a projection of how much weekly quota is
/// still available before the month ends.
public struct MonthOutlook: Sendable, Equatable {
    public var workDaysInMonth: Int
    public var workDaysElapsed: Int
    /// From today (inclusive) to the end of the month.
    public var workDaysLeft: Int
    /// Weekly resets that happen before the month ends.
    public var weeklyResetsLeft: Int?
    /// Quota left this month, in percent of one weekly window (can exceed 100).
    public var projectedPercentLeft: Double?

    /// `projectedPercentLeft` divided by the work days left in the month.
    public var dailyShare: Double? {
        projectedPercentLeft.map { $0 / Double(max(workDaysLeft, 1)) }
    }

    /// Counts only the part of each weekly window whose work days fall inside the month, so a
    /// window that straddles the month end contributes proportionally.
    public static func compute(calendar: WorkCalendar, now: Date, weekly: UsageWindow?) -> Self {
        let monthStart = calendar.startOfMonth(now)
        let monthEnd = calendar.startOfNextMonth(now)
        var outlook = Self(
            workDaysInMonth: calendar.workDays(from: monthStart, to: monthEnd),
            workDaysElapsed: calendar.workDays(from: monthStart, to: now),
            workDaysLeft: calendar.workDays(from: now, to: monthEnd),
            weeklyResetsLeft: nil,
            projectedPercentLeft: nil
        )
        guard let weekly, let firstReset = weekly.resetsAt else { return outlook }

        func fractionInMonth(from start: Date, to end: Date) -> Double {
            let total = calendar.workDays(from: start, to: end)
            guard total > 0 else { return 0 }
            let inside = calendar.workDays(from: max(start, now), to: min(end, monthEnd))
            return Double(inside) / Double(total)
        }

        var projected = weekly.remainingPercent * fractionInMonth(from: now, to: firstReset)
        var resets = 0
        var windowStart = firstReset
        while windowStart < monthEnd {
            resets += 1
            let windowEnd = windowStart.addingTimeInterval(weekly.length)
            projected += 100 * fractionInMonth(from: windowStart, to: windowEnd)
            windowStart = windowEnd
        }
        outlook.weeklyResetsLeft = resets
        outlook.projectedPercentLeft = projected
        return outlook
    }
}
