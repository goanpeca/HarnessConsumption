import Testing

@testable import ConsumptionKit

struct RefreshIntervalTests {
    @Test func defaultIsOneHour() {
        #expect(RefreshInterval.default.seconds == 3600)
        #expect(RefreshInterval(minutes: nil) == .hour1)
    }

    @Test func unknownStoredValuesFallBackToDefault() {
        #expect(RefreshInterval(minutes: 1) == .hour1)
        #expect(RefreshInterval(minutes: 0) == .hour1)
        #expect(RefreshInterval(minutes: 15) == .minutes15)
    }

    @Test func shortestIntervalIsFiveMinutes() {
        #expect(RefreshInterval.allCases.map(\.seconds).min() == 300)
    }
}
