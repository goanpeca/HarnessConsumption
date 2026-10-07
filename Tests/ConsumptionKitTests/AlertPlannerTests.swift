import Foundation
import Testing
@testable import ConsumptionKit

struct AlertPlannerTests {
    let calendar = Fixtures.calendar
    let planner = AlertPlanner()

    func usage(_ windows: UsageWindow..., provider: Provider = .codex) -> ProviderUsage {
        ProviderUsage(provider: provider, plan: nil, windows: windows, fetchedAt: .now)
    }

    @Test func morningSummaryOncePerWorkDay() {
        var state = AlertState()
        let early = planner.plan(usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
                                 now: Fixtures.bogota(10, 7, 7), state: &state)
        #expect(early.isEmpty)
        let first = planner.plan(usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
                                 now: Fixtures.bogota(10, 7, 9), state: &state)
        #expect(first.map(\.kind) == [.morningSummary])
        #expect(first.first?.body == "Codex: 100% of week left, 25% today")
        let again = planner.plan(usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
                                 now: Fixtures.bogota(10, 7, 10), state: &state)
        #expect(again.isEmpty)
    }

    @Test func noSummaryOnHolidays() {
        var state = AlertState()
        let alerts = planner.plan(usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
                                  now: Fixtures.bogota(10, 12, 9), state: &state)
        #expect(alerts.isEmpty)
    }

    @Test func overPaceAndNearlyOutAlertOnce() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let now = Fixtures.bogota(10, 7, 11)
        let alerts = planner.plan(usages: [usage(Fixtures.weekly(used: 95))], calendar: calendar, now: now, state: &state)
        #expect(Set(alerts.map(\.kind)) == [.overPace, .nearlyOut])
        let repeated = planner.plan(usages: [usage(Fixtures.weekly(used: 96))], calendar: calendar, now: now, state: &state)
        #expect(repeated.isEmpty)
    }

    @Test func weeklyResetAlerts() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 14)
        let old = UsageWindow(kind: .weekly, usedPercent: 60, resetsAt: Fixtures.bogota(10, 14, 8, 52))
        _ = planner.plan(usages: [usage(old)], calendar: calendar, now: Fixtures.bogota(10, 14, 8), state: &state)
        let new = UsageWindow(kind: .weekly, usedPercent: 0, resetsAt: Fixtures.bogota(10, 21, 8, 52))
        let alerts = planner.plan(usages: [usage(new)], calendar: calendar, now: Fixtures.bogota(10, 14, 9), state: &state)
        #expect(alerts.map(\.kind) == [.reset])
        #expect(alerts.first?.title == "Codex weekly limit reset")
    }

    @Test func lightSessionResetIsQuiet() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let first = UsageWindow(kind: .session, usedPercent: 20, resetsAt: Fixtures.bogota(10, 7, 10))
        _ = planner.plan(usages: [usage(first)], calendar: calendar, now: Fixtures.bogota(10, 7, 9), state: &state)
        let next = UsageWindow(kind: .session, usedPercent: 0, resetsAt: Fixtures.bogota(10, 7, 15))
        #expect(planner.plan(usages: [usage(next)], calendar: calendar, now: Fixtures.bogota(10, 7, 11),
                             state: &state).isEmpty)
    }
}
