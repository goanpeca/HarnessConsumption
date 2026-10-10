import Foundation

/// A calendar date without a time, e.g. a holiday.
public struct Day: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `yyyy-MM-dd`.
    public init?(iso: String) {
        let parts = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public init(_ date: Date, calendar: Calendar) {
        self.init(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date))
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

/// The counted weekdays minus holidays, evaluated in one time zone.
public struct WorkCalendar: Sendable {
    public let holidays: Set<Day>
    /// `Calendar` weekday numbers that count (1 = Sunday).
    public let workWeekdays: Set<Int>
    public let calendar: Calendar

    public static let colombia = TimeZone(identifier: "America/Bogota") ?? .gmt

    public init(
        holidays: Set<Day>, workWeekdays: Set<Int> = WorkSettings.monToFri,
        timeZone: TimeZone = .current
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.holidays = holidays
        self.workWeekdays = workWeekdays
        self.calendar = calendar
    }

    public func isWorkDay(_ date: Date) -> Bool {
        workWeekdays.contains(calendar.component(.weekday, from: date))
            && !holidays.contains(Day(date, calendar: calendar))
    }

    public func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// Work days whose calendar date falls in `[start's day, end's day)`.
    public func workDays(from start: Date, to end: Date) -> Int {
        var day = startOfDay(start)
        let last = startOfDay(end)
        var count = 0
        while day < last {
            if isWorkDay(day) { count += 1 }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? last
        }
        return count
    }

    public func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    public func startOfNextMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.end ?? startOfDay(date).addingTimeInterval(31 * 86_400)
    }
}
