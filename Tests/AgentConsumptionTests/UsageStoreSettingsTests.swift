import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

@MainActor
struct UsageStoreSettingsTests {
    @Test func settingsPersistAndTheCalendarFollowsAtOnce() {
        let sandbox = Sandbox()
        let harness = StoreHarness(sandbox: sandbox)
        let saturday = Fixtures.date(2026, 10, 10)
        #expect(!harness.store.calendar.isWorkDay(saturday))
        var everyDay = harness.store.settings
        everyDay.weekdays = Set(1...7)
        harness.store.update(everyDay)
        #expect(harness.store.calendar.isWorkDay(saturday))
        #expect(StoreHarness(sandbox: sandbox, settings: nil).store.settings.weekdays == Set(1...7))
    }

    @Test func noWorkdaysAtAllIsRejected() {
        let harness = StoreHarness()
        var none = harness.store.settings
        none.weekdays = []
        harness.store.update(none)
        #expect(!harness.store.settings.weekdays.isEmpty)
    }

    @Test func identicalSettingsAreIgnored() {
        let harness = StoreHarness()
        let before = harness.store.settings
        harness.store.update(before)
        #expect(harness.store.settings == before)
    }

    @Test func aHolidayCountryLoadsItsHolidaysIntoTheCalendar() async {
        let harness = StoreHarness(settings: WorkSettings(countryCode: "CO", isConfigured: true))
        await harness.store.refresh(notify: false)
        #expect(!harness.store.holidaysMissing)
        let columbusDay = Fixtures.date(2026, 10, 12)
        #expect(!harness.store.calendar.isWorkDay(columbusDay))
        #expect(harness.holidaySession.requests.contains { $0.url?.path.hasSuffix("/CO") == true })
    }

    @Test func holidaysThatCannotBeLoadedAreFlaggedAndIgnored() async {
        let harness = StoreHarness(
            settings: WorkSettings(countryCode: "CO", isConfigured: true),
            holidayReply: { _ in .json("[]", status: 500) })
        await harness.store.refresh(notify: false)
        #expect(harness.store.holidaysMissing)
        #expect(harness.store.calendar.isWorkDay(Fixtures.date(2026, 10, 12)))
    }

    @Test func noCountryMeansNoHolidayRequests() async {
        let harness = StoreHarness(settings: WorkSettings(countryCode: nil, isConfigured: true))
        await harness.store.refresh(notify: false)
        #expect(harness.holidaySession.requests.isEmpty)
        #expect(!harness.store.holidaysMissing)
    }

    @Test func turningHolidaysOffStopsRequestingThem() async {
        let harness = StoreHarness(settings: WorkSettings(countryCode: "CO", skipHolidays: false, isConfigured: true))
        await harness.store.refresh(notify: false)
        #expect(harness.holidaySession.requests.isEmpty)
        #expect(harness.store.calendar.isWorkDay(Fixtures.date(2026, 10, 12)))
    }

    @Test func countriesLoadOnceAndAreKept() async {
        let json = #"[{"countryCode":"US","name":"United States"},{"countryCode":"CO","name":"Colombia"}]"#
        let harness = StoreHarness(holidayReply: { _ in .json(json) })
        await harness.store.loadCountries()
        #expect(harness.store.countries.map(\.code) == ["CO", "US"])
        await harness.store.loadCountries()
        #expect(harness.holidaySession.requests.count == 1)
    }

    @Test func aCountryListThatCannotBeLoadedLeavesTheListEmpty() async {
        let harness = StoreHarness(holidayReply: { _ in .json("[]", status: 503) })
        await harness.store.loadCountries()
        #expect(harness.store.countries.isEmpty)
    }
}
