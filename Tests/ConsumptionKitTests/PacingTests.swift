import Foundation
import Testing

@testable import ConsumptionKit

struct PacingTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.bogota(10, 7, 9, 30)  // Wed, window started 08:52 today

    @Test func freshWeekSplitsAcrossFourWorkDays() throws {
        // Oct 7, 8, 9, 13 (12 is a holiday; 14 is the reset day).
        let pace = try #require(WindowPace.compute(window: Fixtures.weekly(used: 0), calendar: calendar, now: now))
        #expect(pace.totalWorkDays == 4)
        #expect(pace.elapsedWorkDays == 0)
        #expect(pace.workDaysLeft == 4)
        #expect(pace.todayShare == 25)
        #expect(pace.targetUsedByEndOfToday == 25)
        #expect(!pace.isOverPace)
    }

    @Test func usingMoreThanTodaysShareIsOverPace() throws {
        let pace = try #require(WindowPace.compute(window: Fixtures.weekly(used: 30), calendar: calendar, now: now))
        #expect(pace.isOverPace)
        #expect(pace.todayShare == 70.0 / 4)
    }

    @Test func laterInTheWeekTargetGrows() throws {
        let friday = Fixtures.bogota(10, 9, 12)
        let pace = try #require(WindowPace.compute(window: Fixtures.weekly(used: 70), calendar: calendar, now: friday))
        #expect(pace.elapsedWorkDays == 2)
        #expect(pace.workDaysLeft == 2)
        #expect(pace.targetUsedByEndOfToday == 75)
        #expect(!pace.isOverPace)
        #expect(pace.todayShare == 15)
    }

    @Test func noResetMeansNoPace() {
        let window = UsageWindow(kind: .weekly, usedPercent: 10, resetsAt: nil)
        #expect(WindowPace.compute(window: window, calendar: calendar, now: now) == nil)
    }

    @Test func monthOutlookCountsResetsAndPartialLastWindow() throws {
        let outlook = MonthOutlook.compute(calendar: calendar, now: now, weekly: Fixtures.weekly(used: 0))
        #expect(outlook.workDaysInMonth == 21)
        #expect(outlook.workDaysElapsed == 4)
        #expect(outlook.workDaysLeft == 17)
        // Resets Oct 14, 21, 28. The Oct 28 window has 4 work days (Nov 2 is a holiday), 3 in October.
        #expect(outlook.weeklyResetsLeft == 3)
        #expect(outlook.projectedPercentLeft == 375)
        #expect(try #require(outlook.dailyShare) == 375.0 / 17)
    }

    @Test func monthOutlookWithoutWeeklyHasNoProjection() {
        let outlook = MonthOutlook.compute(calendar: calendar, now: now, weekly: nil)
        #expect(outlook.workDaysLeft == 17)
        #expect(outlook.projectedPercentLeft == nil)
    }
}
