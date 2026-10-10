import Foundation

/// Which days count when spreading quota: the weekdays you work, and whether a country's public
/// holidays are days off.
public struct WorkSettings: Codable, Sendable, Equatable {
    /// `Calendar` weekday numbers: 1 = Sunday ... 7 = Saturday.
    public var weekdays: Set<Int>
    /// ISO 3166-1 alpha-2 code; nil means no holidays are known.
    public var countryCode: String?
    /// When true, holidays of `countryCode` are not counted even on a counted weekday.
    public var skipHolidays: Bool

    public init(weekdays: Set<Int> = WorkSettings.monToFri, countryCode: String? = "CO", skipHolidays: Bool = true) {
        self.weekdays = weekdays
        self.countryCode = countryCode
        self.skipHolidays = skipHolidays
    }

    public static let monToFri: Set<Int> = [2, 3, 4, 5, 6]

    /// Weekdays in display order, Monday first.
    public static let displayOrder = [2, 3, 4, 5, 6, 7, 1]

    /// Holidays only matter when a country is chosen and the switch is on.
    public var usesHolidays: Bool { countryCode != nil && skipHolidays }

    public func calendar(holidays: Set<Day>, timeZone: TimeZone = .current) -> WorkCalendar {
        WorkCalendar(
            holidays: usesHolidays ? holidays : [], workWeekdays: weekdays, timeZone: timeZone)
    }
}

public struct Country: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var code: String
    public var name: String
    public var id: String { code }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

extension WorkSettings {
    /// Short names indexed by `Calendar` weekday (1 = Sunday).
    public static let weekdayNames = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]

    /// e.g. "Mon–Fri, skipping Colombia holidays" or "Mon–Fri, Sat; holidays counted".
    public func summary(countries: [Country] = []) -> String {
        let ordered = Self.displayOrder.filter(weekdays.contains)
        var parts: [String] = []
        var index = 0
        while index < ordered.count {
            var end = index
            while end + 1 < ordered.count,
                Self.displayOrder.firstIndex(of: ordered[end + 1])!
                    == Self.displayOrder.firstIndex(of: ordered[end])! + 1
            {
                end += 1
            }
            let first = Self.weekdayNames[ordered[index]]!
            parts.append(
                end - index >= 2
                    ? "\(first)–\(Self.weekdayNames[ordered[end]]!)"
                    : ordered[index...end].map { Self.weekdayNames[$0]! }.joined(separator: ", "))
            index = end + 1
        }
        let days = parts.joined(separator: ", ")
        guard let code = countryCode else { return "\(days); no holidays" }
        let name = countries.first { $0.code == code }?.name ?? code
        return skipHolidays ? "\(days), skipping \(name) holidays" : "\(days); \(name) holidays counted"
    }
}
