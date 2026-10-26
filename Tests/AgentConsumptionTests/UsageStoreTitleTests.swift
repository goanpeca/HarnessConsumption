import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

@MainActor
struct UsageStoreTitleTests {
    @Test func aFreshInstallIsNotSetUpAndTheMenuBarSaysSo() {
        let harness = StoreHarness(settings: nil)
        #expect(!harness.store.settings.isConfigured)
        #expect(harness.store.menuBarTitle == "Set up")
    }

    @Test func completingSetupConfirmsPersistsAndShowsTheReadout() {
        let sandbox = Sandbox()
        let harness = StoreHarness(sandbox: sandbox, settings: nil)
        harness.store.completeSetup()
        #expect(harness.store.settings.isConfigured)
        #expect(harness.store.menuBarTitle != "Set up")
        let reloaded = StoreHarness(sandbox: sandbox, settings: nil)
        #expect(reloaded.store.settings.isConfigured)
    }

    @Test func setupKeepsTheCountryTheUserLeftSelected() {
        let harness = StoreHarness(settings: WorkSettings.firstRun(regionCode: "DE"))
        harness.store.completeSetup()
        #expect(harness.store.settings.countryCode == "DE")
    }

    @Test func beforeAnyReadingEachProviderShowsADash() {
        #expect(StoreHarness().store.menuBarTitle == "✳︎ –  ◎ –")
    }

    @Test func eachProviderShowsItsWeeklyPercentLeft() async {
        let harness = StoreHarness()
        await harness.store.refresh(notify: false)
        #expect(harness.store.menuBarTitle == "✳︎ 62%  ◎ 96%")
    }

    @Test func aFailedCheckKeepsTheLastReadingMarkedWithAQuestionMark() async {
        let ok = LockedBox(true)
        let harness = StoreHarness(claude: { now in
            if !ok.value { throw FetchError("HTTP 500: boom") }
            return StoreHarness.usage(.claude, used: 38, now: now)
        })
        await harness.store.refresh(notify: false)
        #expect(harness.store.states[.claude]?.error == nil)
        ok.value = false
        await harness.store.refresh(notify: false)
        #expect(harness.store.menuBarTitle == "✳︎ 62%?  ◎ 96%")
        #expect(harness.store.states[.claude]?.error == "HTTP 500: boom")
        #expect(harness.store.states[.claude]?.usage != nil)
        #expect(harness.store.states[.codex]?.error == nil)
    }

    @Test func aFirstCheckThatFailsShowsADashAndTheError() async {
        let harness = StoreHarness(codex: { _ in throw FetchError("Open the app") })
        await harness.store.refresh(notify: false)
        #expect(harness.store.menuBarTitle == "✳︎ 62%  ◎ –")
        #expect(harness.store.states[.codex]?.error == "Open the app")
        #expect(harness.store.states[.codex]?.usage == nil)
    }

    @Test func aRecoveredCheckClearsTheError() async {
        let ok = LockedBox(false)
        let harness = StoreHarness(claude: { now in
            if !ok.value { throw FetchError("down") }
            return StoreHarness.usage(.claude, used: 10, now: now)
        })
        await harness.store.refresh(notify: false)
        #expect(harness.store.states[.claude]?.error == "down")
        ok.value = true
        await harness.store.refresh(notify: false)
        #expect(harness.store.states[.claude]?.error == nil)
        #expect(harness.store.menuBarTitle == "✳︎ 90%  ◎ 96%")
    }

    @Test func anErrorWithoutADescriptionStillShowsSomething() async {
        struct Plain: Error {}
        let harness = StoreHarness(claude: { _ in throw Plain() })
        await harness.store.refresh(notify: false)
        #expect(harness.store.states[.claude]?.error?.isEmpty == false)
    }

    @Test func aProviderWithoutAFetcherReportsANotSignedInError() async {
        let sandbox = Sandbox()
        let store = UsageStore(
            notifier: RecordingNotifier(), defaults: sandbox.defaults, supportDirectory: sandbox.directory,
            holidaySession: StubSession { _ in .json("[]", status: 500) }.session, fetchers: [:])
        await store.refresh(notify: false)
        #expect(store.states[.claude]?.error == "No fetcher")
    }

    @Test func aMonthlyOnlyPlanShowsItsMonthlyPercent() async {
        let harness = StoreHarness(claude: { now in
            StoreHarness.usage(.claude, used: 14, kind: .monthly, now: now)
        })
        await harness.store.refresh(notify: false)
        #expect(harness.store.menuBarTitle.hasPrefix("✳︎ 86%"))
    }
}
