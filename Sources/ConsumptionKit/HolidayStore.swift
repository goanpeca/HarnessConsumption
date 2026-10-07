import Foundation

/// Public holidays from the Nager.Date API (https://date.nager.at), cached on disk per year so the
/// app works offline after the first fetch.
public actor HolidayStore {
    public let countryCode: String
    private let directory: URL
    private let session: URLSession
    private var memory: [Int: Set<Day>] = [:]

    public init(countryCode: String = "CO", directory: URL, session: URLSession = .shared) {
        self.countryCode = countryCode
        self.directory = directory
        self.session = session
    }

    /// Holidays for the given years. Years that can be neither loaded nor fetched are missing from
    /// the result and listed in `missingYears`, so callers can say the count ignores holidays.
    public func holidays(years: Set<Int>) async -> (days: Set<Day>, missingYears: Set<Int>) {
        var days = Set<Day>()
        var missing = Set<Int>()
        for year in years {
            if let cached = try? await load(year: year) {
                days.formUnion(cached)
            } else {
                missing.insert(year)
            }
        }
        return (days, missing)
    }

    private func load(year: Int) async throws -> Set<Day> {
        if let cached = memory[year] { return cached }
        let file = directory.appendingPathComponent("holidays-\(countryCode)-\(year).json")
        if let data = try? Data(contentsOf: file), let days = try? Self.parse(data) {
            memory[year] = days
            return days
        }
        let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/\(countryCode)")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let days = try Self.parse(data)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        memory[year] = days
        return days
    }

    public static func parse(_ data: Data) throws -> Set<Day> {
        struct Holiday: Decodable { let date: String }
        let holidays = try JSONDecoder().decode([Holiday].self, from: data)
        let days = Set(holidays.compactMap { Day(iso: $0.date) })
        guard !days.isEmpty else { throw UsageParseError.invalidPayload("no holidays") }
        return days
    }
}
