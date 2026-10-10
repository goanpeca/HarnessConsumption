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
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

/// Monday-Friday minus public holidays, evaluated in one time zone.
public struct WorkCalendar: Sendable {
    public let holidays: Set<Day>
    public let calendar: Calendar

    public static let colombia = TimeZone(identifier: "America/Bogota")!

    public init(holidays: Set<Day>, timeZone: TimeZone = WorkCalendar.colombia) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.holidays = holidays
        self.calendar = calendar
    }

    public func isWorkDay(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)  // 1 = Sunday
        return (2...6).contains(weekday) && !holidays.contains(Day(date, calendar: calendar))
    }

    public func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// Work days whose calendar date falls in `[start's day, end's day)`.
    public func workDays(from start: Date, to end: Date) -> Int {
        var day = startOfDay(start)
        let last = startOfDay(end)
        var count = 0
        while day < last {
            if isWorkDay(day) { count += 1 }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return count
    }

    public func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    public func startOfNextMonth(_ date: Date) -> Date {
        calendar.date(byAdding: .month, value: 1, to: startOfMonth(date))!
    }
}
