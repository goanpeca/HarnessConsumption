import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

@MainActor
struct UsageStoreRefreshTests {
    @Test func refreshingRecordsTheTimeAndEndsIdle() async {
        let harness = StoreHarness()
        #expect(harness.store.lastRefresh == nil)
        await harness.store.refresh(notify: false)
        #expect(harness.store.lastRefresh != nil)
        #expect(!harness.store.isRefreshing)
    }

    @Test func aRefreshStartedWhileAnotherIsRunningIsIgnored() async {
        let started = Latch()
        let release = Latch()
        let harness = StoreHarness(claude: { now in
            await started.open()
            await release.wait()
            return StoreHarness.usage(.claude, used: 38, now: now)
        })
        async let first: Void = harness.store.refresh(notify: false)
        await started.wait()  // the first refresh is now held inside its fetch
        #expect(harness.store.isRefreshing)
        await harness.store.refresh(notify: false)  // overlaps it, and must do nothing
        #expect(harness.claudeCalls.value == 1)
        #expect(harness.codexCalls.value == 1)
        await release.open()
        await first
        #expect(!harness.store.isRefreshing)
        #expect(harness.claudeCalls.value == 1)
        #expect(harness.codexCalls.value == 1)
    }

    @Test func aLaterRefreshFetchesAgain() async {
        let harness = StoreHarness()
        await harness.store.refresh(notify: false)
        await harness.store.refresh(notify: false)
        #expect(harness.claudeCalls.value == 2)
    }

    @Test func theRefreshIntervalPersistsAndRepeatsAreIgnored() {
        let sandbox = Sandbox()
        let harness = StoreHarness(sandbox: sandbox)
        #expect(harness.store.refreshInterval == .default)
        harness.store.setRefreshInterval(.minutes15)
        #expect(harness.store.refreshInterval == .minutes15)
        #expect(StoreHarness(sandbox: sandbox).store.refreshInterval == .minutes15)
        harness.store.setRefreshInterval(.minutes15)
        #expect(harness.store.refreshInterval == .minutes15)
    }

    private func nearlyOut() -> (UsageFetch, UsageFetch) {
        (
            { now in StoreHarness.usage(.claude, used: 95, now: now) },
            { now in StoreHarness.usage(.codex, used: 1, now: now) }
        )
    }

    @Test func aNearlyUsedUpLimitNotifiesOnceNotOnEveryRefresh() async {
        let (claude, codex) = nearlyOut()
        let harness = StoreHarness(claude: claude, codex: codex)
        await harness.store.refresh()
        #expect(harness.notifier.count(.nearlyOut) == 1)
        await harness.store.refresh()
        #expect(harness.notifier.count(.nearlyOut) == 1)
    }

    @Test func theOnceOnlyMemorySurvivesARestart() async {
        let sandbox = Sandbox()
        let (claude, codex) = nearlyOut()
        let first = StoreHarness(sandbox: sandbox, claude: claude, codex: codex)
        await first.store.refresh()
        let second = StoreHarness(sandbox: sandbox, claude: claude, codex: codex)
        await second.store.refresh()
        #expect(first.notifier.count(.nearlyOut) == 1)
        #expect(second.notifier.count(.nearlyOut) == 0)
    }

    @Test func aDumpRefreshPostsNothingAndDoesNotUseUpTheAlert() async {
        let (claude, codex) = nearlyOut()
        let harness = StoreHarness(claude: claude, codex: codex)
        await harness.store.refresh(notify: false)
        #expect(harness.notifier.posted.isEmpty)
        await harness.store.refresh()
        #expect(harness.notifier.count(.nearlyOut) == 1)
    }

    @Test func paceAndOutlookAppearOnceThereIsAReading() async {
        let harness = StoreHarness()
        #expect(harness.store.pace(.claude, .weekly) == nil)
        await harness.store.refresh(notify: false)
        #expect(harness.store.pace(.claude, .weekly) != nil)
        #expect(harness.store.pace(.claude, .session) == nil)
        #expect(harness.store.monthOutlook(.claude).workDaysInMonth > 0)
    }

    @Test func theDumpReportListsTheTitleProvidersAndErrors() async {
        let harness = StoreHarness(codex: { _ in throw FetchError("Open the app") })
        await harness.store.refresh(notify: false)
        let report = harness.store.report
        #expect(report.hasPrefix("menu bar: ✳︎ 62%  ◎ –"))
        #expect(report.contains("Claude (test)"))
        #expect(report.contains("  error: Open the app"))
        #expect(report.contains("Weekly: 62% left"))
        #expect(report.contains("counted days:"))
    }

    @Test func theDumpReportIncludesTheBudgetLine() async {
        let (claude, codex) = StoreHarness.spending(claude: 1_000, codexCredits: 10_000)
        let harness = StoreHarness(budget: BudgetSettings(), claude: claude, codex: codex)
        await harness.store.refresh(notify: false)
        #expect(harness.store.report.contains("Shared budget: $2000 of $4000 spent, 50% left"))
    }
}
