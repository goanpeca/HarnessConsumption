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
    /// False until the user confirms their settings on first launch.
    public var isConfigured: Bool

    public init(
        weekdays: Set<Int> = Self.monToFri, countryCode: String? = nil, skipHolidays: Bool = true,
        isConfigured: Bool = true
    ) {
        self.weekdays = weekdays
        self.countryCode = countryCode
        self.skipHolidays = skipHolidays
        self.isConfigured = isConfigured
    }

    /// Settings for a fresh install: the system region is only a suggestion until the user confirms it.
    public static func firstRun(regionCode: String?) -> Self {
        Self(countryCode: regionCode, isConfigured: false)
    }

    /// Settings saved before first-run setup existed were chosen by the user, so they count as configured.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekdays = try container.decode(Set<Int>.self, forKey: .weekdays)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        skipHolidays = try container.decode(Bool.self, forKey: .skipHolidays)
        isConfigured = try container.decodeIfPresent(Bool.self, forKey: .isConfigured) ?? true
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
    private static let shortNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public static func weekdayName(_ weekday: Int) -> String {
        shortNames.indices.contains(weekday - 1) ? shortNames[weekday - 1] : "?"
    }

    /// e.g. "Mon–Fri, skipping Colombia holidays" or "Mon–Fri, Sat; holidays counted".
    public func summary(countries: [Country] = []) -> String {
        // Positions in Monday-first order, grouped into runs of consecutive days.
        let positions = Self.displayOrder.indices.filter { weekdays.contains(Self.displayOrder[$0]) }
        var runs: [[Int]] = []
        for position in positions {
            if let last = runs.last?.last, last + 1 == position {
                runs[runs.count - 1].append(position)
            } else {
                runs.append([position])
            }
        }
        let days = runs.map { run -> String in
            let names = run.map { Self.weekdayName(Self.displayOrder[$0]) }
            return run.count >= 3 ? "\(names[0])–\(names[names.count - 1])" : names.joined(separator: ", ")
        }.joined(separator: ", ")
        guard let code = countryCode else { return "\(days); no holidays" }
        let name = countries.first { $0.code == code }?.name ?? code
        return skipHolidays ? "\(days), skipping \(name) holidays" : "\(days); \(name) holidays counted"
    }
}
