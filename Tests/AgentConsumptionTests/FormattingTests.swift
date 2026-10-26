import Foundation
import Testing

@testable import AgentConsumption

struct FormattingTests {
    let us = Locale(identifier: "en_US")

    @Test func dollarsRoundToWholeUnitsInTheGivenLocale() {
        #expect(dollars(1234.4, locale: us) == "$1,234")
        #expect(dollars(1234.5, locale: us) == "$1,235")
        #expect(dollars(0, locale: us) == "$0")
        #expect(dollars(1_000_000, locale: us) == "$1,000,000")
    }

    @Test func dollarsFollowTheReadersLocale() {
        #expect(dollars(1234, locale: Locale(identifier: "de_DE")).contains("1.234"))
    }

    @Test func percentShowsADecimalOnlyBelowTen() {
        #expect(percent(9.94) == "9.9%")
        #expect(percent(10) == "10%")
        #expect(percent(12.4) == "12%")
        #expect(percent(99.6) == "100%")
        #expect(percent(0) == "0.0%")
    }

    @Test func daysPluralize() {
        #expect(days(1) == "1 day")
        #expect(days(0) == "0 days")
        #expect(days(5) == "5 days")
    }
}
