import Foundation

/// Public holidays and the list of supported countries from the Nager.Date API
/// (https://date.nager.at), cached on disk so the app works offline after the first fetch.
public actor HolidayStore {
    private let directory: URL
    private let session: URLSession
    private var memory: [String: Set<Day>] = [:]

    public init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
    }

    /// Holidays for the given years. Years that can be neither loaded nor fetched are missing from
    /// the result and listed in `missingYears`, so callers can say the count ignores holidays.
    public func holidays(country: String, years: Set<Int>) async -> (days: Set<Day>, missingYears: Set<Int>) {
        var days = Set<Day>()
        var missing = Set<Int>()
        for year in years {
            if let cached = try? await load(country: country, year: year) {
                days.formUnion(cached)
            } else {
                missing.insert(year)
            }
        }
        return (days, missing)
    }

    /// Countries Nager.Date has holidays for, sorted by name. Falls back to the cache, then to nil.
    public func countries() async -> [Country]? {
        let file = directory.appendingPathComponent("countries.json")
        if let data = try? Data(contentsOf: file), let list = try? Self.parseCountries(data) { return list }
        guard let data = try? await fetch("https://date.nager.at/api/v3/AvailableCountries"),
            let list = try? Self.parseCountries(data)
        else { return nil }
        try? write(data, to: file)
        return list
    }

    /// Country codes end up in a file name and a URL, so only ISO 3166-1 alpha-2 codes are allowed.
    public static func isValidCountryCode(_ code: String) -> Bool {
        code.count == 2 && code.utf8.allSatisfy { (65...90).contains($0) }
    }

    private func load(country: String, year: Int) async throws -> Set<Day> {
        guard Self.isValidCountryCode(country), (1900...2200).contains(year) else {
            throw URLError(.badURL)
        }
        let key = "\(country)-\(year)"
        if let cached = memory[key] { return cached }
        let file = directory.appendingPathComponent("holidays-\(key).json")
        if let data = try? Data(contentsOf: file), let days = try? Self.parse(data) {
            memory[key] = days
            return days
        }
        let data = try await fetch("https://date.nager.at/api/v3/PublicHolidays/\(year)/\(country)")
        let days = try Self.parse(data)
        try write(data, to: file)
        memory[key] = days
        return days
    }

    private func fetch(_ url: String) async throws -> Data {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private func write(_ data: Data, to file: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }

    public static func parse(_ data: Data) throws -> Set<Day> {
        struct Holiday: Decodable { let date: String }
        let holidays = try JSONDecoder().decode([Holiday].self, from: data)
        let days = Set(holidays.compactMap { Day(iso: $0.date) })
        guard !days.isEmpty else { throw UsageParseError.invalidPayload("no holidays") }
        return days
    }

    public static func parseCountries(_ data: Data) throws -> [Country] {
        struct Entry: Decodable {
            let countryCode: String
            let name: String
        }
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        guard !entries.isEmpty else { throw UsageParseError.invalidPayload("no countries") }
        return entries.map { Country(code: $0.countryCode, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
