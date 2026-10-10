import Foundation
import Testing

@testable import ConsumptionKit

struct HolidayStoreTests {
    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func readsCachedYearWithoutNetwork() async throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = #"[{"date":"2026-10-12"},{"date":"2026-11-02"}]"#
        try Data(json.utf8).write(to: directory.appendingPathComponent("holidays-CO-2026.json"))

        let store = HolidayStore(directory: directory, session: offlineSession())
        let result = await store.holidays(country: "CO", years: [2026])
        #expect(result.days == [Day(year: 2026, month: 10, day: 12), Day(year: 2026, month: 11, day: 2)])
        #expect(result.missingYears.isEmpty)
    }

    @Test func reportsYearsThatCannotBeLoaded() async throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HolidayStore(directory: directory, session: offlineSession())
        let result = await store.holidays(country: "CO", years: [2031])
        #expect(result.days.isEmpty)
        #expect(result.missingYears == [2031])
    }

    @Test func countriesAreCachedPerCountryAndSortedByName() async throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = #"[{"countryCode":"US","name":"United States"},{"countryCode":"CO","name":"Colombia"}]"#
        try Data(json.utf8).write(to: directory.appendingPathComponent("countries.json"))
        try Data(#"[{"date":"2026-07-04"}]"#.utf8).write(to: directory.appendingPathComponent("holidays-US-2026.json"))

        let store = HolidayStore(directory: directory, session: offlineSession())
        #expect(
            await store.countries() == [
                Country(code: "CO", name: "Colombia"), Country(code: "US", name: "United States"),
            ])
        let us = await store.holidays(country: "US", years: [2026])
        #expect(us.days == [Day(year: 2026, month: 7, day: 4)])
        #expect(await store.holidays(country: "CO", years: [2026]).missingYears == [2026])
    }

    @Test func rejectsCountryCodesThatCouldEscapeTheCacheOrURL() async throws {
        #expect(HolidayStore.isValidCountryCode("CO"))
        for bad in ["", "C", "COL", "co", "../", "C/", "C?", "1A", "../../x"] {
            #expect(!HolidayStore.isValidCountryCode(bad), "\(bad)")
        }
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HolidayStore(directory: directory, session: offlineSession())
        let result = await store.holidays(country: "../../x", years: [2026])
        #expect(result.days.isEmpty)
        #expect(result.missingYears == [2026])
    }

    @Test func rejectsEmptyHolidayList() {
        #expect(throws: UsageParseError.self) { try HolidayStore.parse(Data("[]".utf8)) }
    }

    /// A session whose every request fails immediately.
    private func offlineSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class FailingProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
