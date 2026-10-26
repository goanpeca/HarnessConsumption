import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

/// R11: color is never the only signal and each row reads as one VoiceOver element. The spoken text is
/// what VoiceOver says, so these pin it down.
@MainActor
struct AccessibilityTests {
    let now = Date(timeIntervalSince1970: 1_791_383_288)  // Wed 2026-10-07 UTC
    var calendar: WorkCalendar {
        WorkSettings(countryCode: nil).calendar(holidays: [], timeZone: TimeZone(identifier: "UTC") ?? .gmt)
    }

    private func weekly(used: Double) -> UsageWindow {
        UsageWindow(kind: .weekly, usedPercent: used, resetsAt: now.addingTimeInterval(3 * 86_400), length: 7 * 86_400)
    }

    @Test func aWeeklyRowSpeaksPercentStatusResetAndTodaysShare() {
        let window = weekly(used: 38)
        let pace = WindowPace.compute(window: window, calendar: calendar, now: now)
        let spoken = WindowRow(window: window, pace: pace).spokenSummary
        #expect(spoken.hasPrefix("62 percent left. On pace. Resets "))
        #expect(spoken.contains("Today "))
        #expect(spoken.contains("of the limit"))
        #expect(spoken.contains("left"))
    }

    @Test func aRowThatIsOverPaceSaysSoInWordsNotJustColor() {
        let window = weekly(used: 90)
        let pace = WindowPace.compute(window: window, calendar: calendar, now: now)
        let spoken = WindowRow(window: window, pace: pace).spokenSummary
        #expect(
            spoken.contains("percent left. Well over pace") || spoken.contains("Almost out")
                || spoken.contains("Ahead of pace"))
        #expect(!spoken.contains("On pace"))
    }

    @Test func anIdleSessionSaysThereIsNoActiveWindowAndHasNoPerDayShare() {
        let idle = UsageWindow(kind: .session, usedPercent: 0, resetsAt: nil)
        let spoken = WindowRow(window: idle, pace: nil).spokenSummary
        #expect(spoken == "100 percent left. Plenty left. No active window")
    }

    @Test func aSessionWindowNeverSpeaksAPerDayShare() {
        let session = UsageWindow(kind: .session, usedPercent: 20, resetsAt: now.addingTimeInterval(3_600))
        let pace = WindowPace.compute(window: session, calendar: calendar, now: now)
        #expect(!WindowRow(window: session, pace: pace).spokenSummary.contains("Today"))
    }

    @Test func theBudgetCardSpeaksPercentDollarsStatusAndPerDay() async {
        let spend: UsageFetch = { now in
            StoreHarness.usage(
                .claude, used: 40, kind: .monthly, spend: SpendReading(used: 1_000, limit: 4_200, unit: .usd), now: now)
        }
        let harness = StoreHarness(budget: BudgetSettings(totalUSD: 4000), claude: spend)
        await harness.store.refresh(notify: false)
        let status = harness.store.budgetPools[0]
        let pace = status.pace(calendar: harness.store.calendar, now: .now)
        let spoken = BudgetSection(store: harness.store, status: status).spoken(status, pace: pace)
        #expect(spoken.hasPrefix("75 percent left. "))
        #expect(spoken.contains("\(dollars(3_000)) of \(dollars(4_000)) left"))
        #expect(spoken.contains(status.window.status(pace: pace)))
        if pace != nil { #expect(spoken.contains("per work day")) }
    }

    @Test func theBudgetCardOmitsThePerDayPartWithoutAResetDate() {
        let harness = StoreHarness(budget: BudgetSettings(totalUSD: 4000))
        let noReset = UsageWindow(kind: .monthly, usedPercent: 0, resetsAt: nil)
        let usage = ProviderUsage(
            provider: .claude, plan: nil, windows: [noReset], fetchedAt: now,
            spend: SpendReading(used: 1_000, limit: 4_200, unit: .usd))
        guard let status = BudgetStatus.compute(usages: [usage], settings: BudgetSettings(totalUSD: 4000)) else {
            Issue.record("expected a budget status")
            return
        }
        #expect(status.window.resetsAt == nil)
        let spoken = BudgetSection(store: harness.store, status: status).spoken(status, pace: nil)
        #expect(!spoken.contains("per work day"))
        #expect(spoken.contains("75 percent left"))
    }

    @Test func everyLevelHasADifferentSymbolAndAStatusWordSoColorIsNeverAlone() {
        let words = Set(
            [0.0, 80, 99].map { UsageWindow(kind: .session, usedPercent: $0, resetsAt: nil).status(pace: nil) })
        #expect(words.count == 3)
        #expect(Set([UsageLevel.good, .watch, .critical].map(\.symbol)).count == 3)
    }
}
