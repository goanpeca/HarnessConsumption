import Foundation
import Testing

@testable import ConsumptionKit

struct UsageLevelTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.bogota(10, 26)
    let reset = Fixtures.bogota(11, 1, 0)

    private func window(used: Double) -> UsageWindow {
        UsageWindow(kind: .monthly, usedPercent: used, resetsAt: reset, length: 31 * 86_400)
    }

    private func level(used: Double) -> UsageLevel {
        let window = window(used: used)
        return window.level(pace: WindowPace.compute(window: window, calendar: calendar, now: now))
    }

    @Test func underPaceIsGood() {
        #expect(level(used: 38) == .good)
    }

    @Test func slightlyOverPaceIsWatch() throws {
        let pace = try #require(WindowPace.compute(window: window(used: 0), calendar: calendar, now: now))
        #expect(level(used: pace.targetUsedByEndOfToday + 5) == .watch)
    }

    @Test func farOverPaceIsCritical() throws {
        let pace = try #require(WindowPace.compute(window: window(used: 0), calendar: calendar, now: now))
        #expect(level(used: pace.targetUsedByEndOfToday + 15) == .critical)
    }

    @Test func nearlyEmptyIsCriticalEvenOnPace() {
        #expect(level(used: 95) == .critical)
    }

    @Test func withoutPaceFallsBackToPercentLeft() {
        let idle = UsageWindow(kind: .session, usedPercent: 0, resetsAt: nil)
        #expect(idle.level(pace: nil) == .good)
        #expect(UsageWindow(kind: .session, usedPercent: 80, resetsAt: nil).level(pace: nil) == .watch)
        #expect(UsageWindow(kind: .session, usedPercent: 95, resetsAt: nil).level(pace: nil) == .critical)
    }

    @Test func statusWordsDoNotRelyOnColor() throws {
        let pace = try #require(WindowPace.compute(window: window(used: 0), calendar: calendar, now: now))
        func status(_ used: Double) -> String {
            let window = window(used: used)
            return window.status(pace: WindowPace.compute(window: window, calendar: calendar, now: now))
        }
        #expect(status(38) == "On pace")
        #expect(status(pace.targetUsedByEndOfToday + 5) == "Ahead of pace")
        let early = Fixtures.bogota(10, 14)
        let earlyWindow = window(used: 0)
        let earlyTarget = try #require(WindowPace.compute(window: earlyWindow, calendar: calendar, now: early))
            .targetUsedByEndOfToday
        let farOver = window(used: earlyTarget + 15)
        let farPace = WindowPace.compute(window: farOver, calendar: calendar, now: early)
        #expect(farOver.status(pace: farPace) == "Well over pace")
        #expect(status(95) == "Almost out")
        #expect(UsageWindow(kind: .session, usedPercent: 0, resetsAt: nil).status(pace: nil) == "Plenty left")
        #expect(UsageWindow(kind: .session, usedPercent: 80, resetsAt: nil).status(pace: nil) == "Running low")
    }
}

struct UsageLevelBoundaryTests {
    @Test func tenPercentLeftIsNotYetCriticalButNinePointNineIs() {
        #expect(UsageWindow(kind: .session, usedPercent: 90, resetsAt: nil).level(pace: nil) == .watch)
        #expect(UsageWindow(kind: .session, usedPercent: 90.1, resetsAt: nil).level(pace: nil) == .critical)
    }

    @Test func twentyFivePercentLeftIsTheWatchEdgeWithoutPace() {
        #expect(UsageWindow(kind: .session, usedPercent: 75, resetsAt: nil).level(pace: nil) == .good)
        #expect(UsageWindow(kind: .session, usedPercent: 75.1, resetsAt: nil).level(pace: nil) == .watch)
    }

    @Test func everyLevelHasADistinctStatusWord() {
        let words = [
            UsageWindow(kind: .session, usedPercent: 0, resetsAt: nil).status(pace: nil),
            UsageWindow(kind: .session, usedPercent: 80, resetsAt: nil).status(pace: nil),
            UsageWindow(kind: .session, usedPercent: 99, resetsAt: nil).status(pace: nil),
        ]
        #expect(Set(words).count == 3)
    }
}
