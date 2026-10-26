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
        let early = planner.plan(
            usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
            now: Fixtures.bogota(10, 7, 7), state: &state)
        #expect(early.isEmpty)
        let first = planner.plan(
            usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
            now: Fixtures.bogota(10, 7, 9), state: &state)
        #expect(first.map(\.kind) == [.morningSummary])
        #expect(first.first?.body == "Codex: 100% of week left, 25% today")
        let again = planner.plan(
            usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
            now: Fixtures.bogota(10, 7, 10), state: &state)
        #expect(again.isEmpty)
    }

    @Test func noSummaryOnHolidays() {
        var state = AlertState()
        let alerts = planner.plan(
            usages: [usage(Fixtures.weekly(used: 0))], calendar: calendar,
            now: Fixtures.bogota(10, 12, 9), state: &state)
        #expect(alerts.isEmpty)
    }

    @Test func overPaceAndNearlyOutAlertOnce() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let now = Fixtures.bogota(10, 7, 11)
        let alerts = planner.plan(
            usages: [usage(Fixtures.weekly(used: 95))], calendar: calendar, now: now, state: &state)
        #expect(Set(alerts.map(\.kind)) == [.overPace, .nearlyOut])
        let repeated = planner.plan(
            usages: [usage(Fixtures.weekly(used: 96))], calendar: calendar, now: now, state: &state)
        #expect(repeated.isEmpty)
    }

    @Test func weeklyResetAlerts() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 14)
        let old = UsageWindow(kind: .weekly, usedPercent: 60, resetsAt: Fixtures.bogota(10, 14, 8, 52))
        _ = planner.plan(usages: [usage(old)], calendar: calendar, now: Fixtures.bogota(10, 14, 8), state: &state)
        let new = UsageWindow(kind: .weekly, usedPercent: 0, resetsAt: Fixtures.bogota(10, 21, 8, 52))
        let alerts = planner.plan(
            usages: [usage(new)], calendar: calendar, now: Fixtures.bogota(10, 14, 9), state: &state)
        #expect(alerts.map(\.kind) == [.reset])
        #expect(alerts.first?.title == "Codex weekly limit reset")
    }

    @Test func lightSessionResetIsQuiet() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let first = UsageWindow(kind: .session, usedPercent: 20, resetsAt: Fixtures.bogota(10, 7, 10))
        _ = planner.plan(usages: [usage(first)], calendar: calendar, now: Fixtures.bogota(10, 7, 9), state: &state)
        let next = UsageWindow(kind: .session, usedPercent: 0, resetsAt: Fixtures.bogota(10, 7, 15))
        #expect(
            planner.plan(
                usages: [usage(next)], calendar: calendar, now: Fixtures.bogota(10, 7, 11),
                state: &state
            ).isEmpty)
    }
}

struct AlertThresholdTests {
    let calendar = Fixtures.calendar
    let planner = AlertPlanner()
    let now = Fixtures.bogota(10, 7, 11)

    private func usage(_ window: UsageWindow) -> ProviderUsage {
        ProviderUsage(provider: .codex, plan: nil, windows: [window], fetchedAt: .now)
    }

    private func kinds(used: Double) -> Set<UsageAlert.Kind> {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let alerts = planner.plan(
            usages: [usage(Fixtures.weekly(used: used))], calendar: calendar, now: now, state: &state)
        return Set(alerts.map(\.kind))
    }

    @Test func nearlyOutStartsBelowTenPercentLeft() {
        #expect(AlertPlanner().nearlyOutThreshold == 10)
        #expect(!kinds(used: 85).contains(.nearlyOut))
        #expect(!kinds(used: 90).contains(.nearlyOut))
        #expect(kinds(used: 90.1).contains(.nearlyOut))
    }

    @Test func smallResetTimeJitterIsNotAReset() {
        func alerts(shift: TimeInterval) -> [UsageAlert] {
            var state = AlertState()
            state.lastSummaryDay = Day(year: 2026, month: 10, day: 14)
            let first = UsageWindow(kind: .weekly, usedPercent: 60, resetsAt: Fixtures.bogota(10, 14, 8, 52))
            _ = planner.plan(usages: [usage(first)], calendar: calendar, now: Fixtures.bogota(10, 14, 8), state: &state)
            let second = UsageWindow(
                kind: .weekly, usedPercent: 60, resetsAt: Fixtures.bogota(10, 14, 8, 52).addingTimeInterval(shift))
            return planner.plan(
                usages: [usage(second)], calendar: calendar, now: Fixtures.bogota(10, 14, 9), state: &state)
        }
        #expect(!alerts(shift: 200).contains { $0.kind == .reset })
        #expect(alerts(shift: 400).contains { $0.kind == .reset })
    }
}

struct AlertSummaryTests {
    let calendar = Fixtures.calendar
    let planner = AlertPlanner()
    let morning = Fixtures.bogota(10, 7, 9)

    private func summary(_ usages: [ProviderUsage]) -> String? {
        var state = AlertState()
        return planner.plan(usages: usages, calendar: calendar, now: morning, state: &state)
            .first { $0.kind == .morningSummary }?.body
    }

    private func usage(_ provider: Provider, _ windows: UsageWindow...) -> ProviderUsage {
        ProviderUsage(provider: provider, plan: nil, windows: windows, fetchedAt: morning)
    }

    @Test func aMonthlyOnlyPlanSummarizesItsMonthlyLimit() {
        let monthly = UsageWindow(kind: .monthly, usedPercent: 14, resetsAt: nil)
        #expect(summary([usage(.claude, monthly)]) == "Claude: 86% of monthly limit left")
    }

    @Test func aProviderWithNoWeeklyOrMonthlyDataSaysSo() {
        let session = UsageWindow(kind: .session, usedPercent: 10, resetsAt: nil)
        #expect(summary([usage(.codex, session)]) == "Codex: no weekly data")
    }

    @Test func providersAreJoinedOnOneLine() {
        let weekly = Fixtures.weekly(used: 0)
        let monthly = UsageWindow(kind: .monthly, usedPercent: 50, resetsAt: nil)
        let body = summary([usage(.claude, weekly), usage(.codex, monthly)])
        #expect(body == "Claude: 100% of week left, 25% today · Codex: 50% of monthly limit left")
    }

    @Test func aWeeklyWithoutAResetDateOmitsTodaysShare() {
        let weekly = UsageWindow(kind: .weekly, usedPercent: 20, resetsAt: nil)
        #expect(summary([usage(.claude, weekly)]) == "Claude: 80% of week left")
    }

    @Test func noProvidersMeansNoSummary() {
        var state = AlertState()
        let alerts = planner.plan(usages: [], calendar: calendar, now: morning, state: &state)
        #expect(alerts.filter { $0.kind == .morningSummary }.allSatisfy { $0.body.isEmpty })
    }

    @Test func theSummaryWaitsUntilTheMorningHour() {
        var state = AlertState()
        let early = Fixtures.bogota(10, 7, 7)
        let alerts = planner.plan(
            usages: [usage(.claude, Fixtures.weekly(used: 0))], calendar: calendar, now: early, state: &state)
        #expect(!alerts.contains { $0.kind == .morningSummary })
    }

    @Test func aCustomMorningHourIsHonored() {
        var custom = AlertPlanner()
        custom.morningHour = 11
        var state = AlertState()
        let ten = Fixtures.bogota(10, 7, 10)
        #expect(
            !custom.plan(
                usages: [usage(.claude, Fixtures.weekly(used: 0))], calendar: calendar, now: ten, state: &state
            )
            .contains { $0.kind == .morningSummary })
        let noon = Fixtures.bogota(10, 7, 12)
        #expect(
            custom.plan(
                usages: [usage(.claude, Fixtures.weekly(used: 0))], calendar: calendar, now: noon, state: &state
            )
            .contains { $0.kind == .morningSummary })
    }
}

struct AlertDedupTests {
    let calendar = Fixtures.calendar
    let planner = AlertPlanner()
    let now = Fixtures.bogota(10, 7, 11)

    private func nearlyOut(resetAt reset: Date) -> ProviderUsage {
        let window = UsageWindow(kind: .weekly, usedPercent: 95, resetsAt: reset, length: 7 * 86_400)
        return ProviderUsage(provider: .codex, plan: nil, windows: [window], fetchedAt: now)
    }

    private func alerts(_ reset: Date, state: inout AlertState) -> [UsageAlert] {
        planner.plan(usages: [nearlyOut(resetAt: reset)], calendar: calendar, now: now, state: &state)
            .filter { $0.kind == .nearlyOut }
    }

    @Test func aResetTimeThatWobblesAcrossAMinuteBoundaryDoesNotAlertAgain() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        // 5 seconds before a minute boundary, then 10 seconds later: the same window, a different minute.
        let boundary = Fixtures.bogota(10, 14, 8, 52)
        let first = boundary.addingTimeInterval(-5)
        let second = boundary.addingTimeInterval(5)
        #expect(Int(first.timeIntervalSince1970 / 60) != Int(second.timeIntervalSince1970 / 60))
        #expect(alerts(first, state: &state).count == 1)
        #expect(alerts(second, state: &state).isEmpty)
        #expect(alerts(boundary.addingTimeInterval(-30), state: &state).isEmpty)
    }

    @Test func aGenuinelyNewWindowAlertsAgain() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let reset = Fixtures.bogota(10, 14, 8, 52)
        #expect(alerts(reset, state: &state).count == 1)
        #expect(alerts(reset.addingTimeInterval(7 * 86_400), state: &state).count == 1)
    }

    @Test func aWindowThatMovesEarlierIsANewWindowToo() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let reset = Fixtures.bogota(10, 14, 8, 52)
        #expect(alerts(reset, state: &state).count == 1)
        #expect(alerts(reset.addingTimeInterval(-3_600), state: &state).count == 1)
    }

    @Test func driftWithinTheToleranceNeverAccumulatesIntoAnAlert() {
        var state = AlertState()
        state.lastSummaryDay = Day(year: 2026, month: 10, day: 7)
        let reset = Fixtures.bogota(10, 14, 8, 52)
        #expect(alerts(reset, state: &state).count == 1)
        for step in 1...8 { #expect(alerts(reset.addingTimeInterval(Double(step) * 20), state: &state).isEmpty) }
    }
}
