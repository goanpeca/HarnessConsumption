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

        let store = HolidayStore(countryCode: "CO", directory: directory, session: offlineSession())
        let result = await store.holidays(years: [2026])
        #expect(result.days == [Day(year: 2026, month: 10, day: 12), Day(year: 2026, month: 11, day: 2)])
        #expect(result.missingYears.isEmpty)
    }

    @Test func reportsYearsThatCannotBeLoaded() async throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HolidayStore(countryCode: "CO", directory: directory, session: offlineSession())
        let result = await store.holidays(years: [2031])
        #expect(result.days.isEmpty)
        #expect(result.missingYears == [2031])
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
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
