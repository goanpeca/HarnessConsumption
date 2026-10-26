import Foundation
import Testing

@testable import ConsumptionKit

struct DayTests {
    @Test func parsesIsoDatesAndIgnoresATimeSuffix() {
        #expect(Day(iso: "2026-10-12") == Day(year: 2026, month: 10, day: 12))
        #expect(Day(iso: "2026-10-12T00:00:00Z") == Day(year: 2026, month: 10, day: 12))
    }

    @Test func rejectsShapesThatAreNotDates() {
        for bad in ["", "2026", "2026-10", "x-y-z", "2026/10/12", "2026-10-"] {
            #expect(Day(iso: bad) == nil, "\(bad)")
        }
    }

    @Test func rejectsDatesThatDoNotExist() {
        for bad in ["2026-13-01", "2026-00-10", "2026-10-00", "2026-10-32", "2026-02-30", "2026-04-31", "2027-02-29"] {
            #expect(Day(iso: bad) == nil, "\(bad)")
        }
    }

    @Test func acceptsTheLastDayOfEveryMonthAndLeapDay() {
        #expect(Day(iso: "2028-02-29") != nil)
        #expect(Day(iso: "2026-02-28") != nil)
        #expect(Day(iso: "2026-04-30") != nil)
        #expect(Day(iso: "2026-12-31") != nil)
    }

    @Test func ordersByYearThenMonthThenDay() {
        let days = [
            Day(year: 2027, month: 1, day: 1), Day(year: 2026, month: 12, day: 31), Day(year: 2026, month: 2, day: 9),
            Day(year: 2026, month: 2, day: 10),
        ]
        #expect(days.sorted().map(\.description) == ["2026-02-09", "2026-02-10", "2026-12-31", "2027-01-01"])
        #expect(Day(year: 2026, month: 10, day: 1) < Day(year: 2026, month: 10, day: 2))
        let first = Day(year: 2026, month: 10, day: 2)
        let equal = Day(iso: "2026-10-02")
        #expect(equal.map { !(first < $0) && !($0 < first) } == true)
    }

    @Test func descriptionIsZeroPaddedIso() {
        #expect(Day(year: 2026, month: 3, day: 4).description == "2026-03-04")
        #expect(Day(iso: Day(year: 2026, month: 3, day: 4).description) == Day(year: 2026, month: 3, day: 4))
    }

    @Test func aDateMapsToTheDayInTheCalendarsZone() {
        // Fri 2026-10-09 23:30 in Bogotá is already Sat 2026-10-10 in UTC.
        let instant = Date(timeIntervalSince1970: 1_791_606_600)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota") ?? .gmt
        #expect(Day(instant, calendar: calendar).description == "2026-10-09")
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        #expect(Day(instant, calendar: calendar).description == "2026-10-10")
    }
}

struct WorkCalendarEdgeTests {
    private func calendar(
        _ zone: String = "UTC", weekdays: Set<Int> = WorkSettings.monToFri, holidays: Set<Day> = []
    ) -> WorkCalendar {
        WorkCalendar(holidays: holidays, workWeekdays: weekdays, timeZone: TimeZone(identifier: zone) ?? .gmt)
    }

    private func date(_ zone: String, _ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone) ?? .gmt
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    @Test func aWindowEndingBeforeItStartsCountsNothing() {
        let c = calendar()
        #expect(c.workDays(from: date("UTC", 2026, 10, 14), to: date("UTC", 2026, 10, 7)) == 0)
    }

    @Test func theSameDayCountsNothingAndTheNextDayCountsTheFirst() {
        let c = calendar()
        #expect(c.workDays(from: date("UTC", 2026, 10, 7, 1), to: date("UTC", 2026, 10, 7, 23)) == 0)
        #expect(c.workDays(from: date("UTC", 2026, 10, 7, 23), to: date("UTC", 2026, 10, 8, 1)) == 1)
    }

    @Test func aWeekendOnlyWindowHasNoWorkDays() {
        #expect(calendar().workDays(from: date("UTC", 2026, 10, 10), to: date("UTC", 2026, 10, 12)) == 0)
    }

    @Test func holidaysAreSkippedButOnlyOnCountedWeekdays() {
        let saturdayHoliday = Day(year: 2026, month: 10, day: 10)
        let mondayHoliday = Day(year: 2026, month: 10, day: 12)
        let c = calendar(holidays: [saturdayHoliday, mondayHoliday])
        #expect(!c.isWorkDay(date("UTC", 2026, 10, 12)))
        #expect(c.workDays(from: date("UTC", 2026, 10, 5), to: date("UTC", 2026, 10, 19)) == 9)
    }

    @Test func aSingleCountedWeekdayCountsOncePerWeek() {
        let mondays = calendar(weekdays: [2])
        #expect(mondays.workDays(from: date("UTC", 2026, 10, 1), to: date("UTC", 2026, 11, 1)) == 4)
    }

    @Test func daylightSavingDoesNotChangeTheCount() {
        // US clocks spring forward on 2026-03-08; the window still has 5 weekdays Mon 2 to Mon 9.
        let c = calendar("America/New_York")
        #expect(c.workDays(from: date("America/New_York", 2026, 3, 2), to: date("America/New_York", 2026, 3, 9)) == 5)
        // Fall back on 2026-11-01.
        #expect(
            c.workDays(from: date("America/New_York", 2026, 10, 26), to: date("America/New_York", 2026, 11, 2)) == 5)
    }

    @Test func theSameInstantIsDifferentDaysInDifferentZones() {
        let instant = date("UTC", 2026, 10, 9, 23)  // Fri 23:00 UTC, already Saturday in Auckland
        #expect(calendar("UTC").isWorkDay(instant))
        #expect(!calendar("Pacific/Auckland").isWorkDay(instant))
    }

    @Test func monthBoundariesRollOverTheYear() {
        let c = calendar()
        #expect(c.startOfMonth(date("UTC", 2026, 12, 15)) == date("UTC", 2026, 12, 1, 0))
        #expect(c.startOfNextMonth(date("UTC", 2026, 12, 15)) == date("UTC", 2027, 1, 1, 0))
        #expect(c.startOfNextMonth(date("UTC", 2028, 2, 10)) == date("UTC", 2028, 3, 1, 0))
        #expect(c.startOfNextMonth(date("UTC", 2026, 2, 10)) == date("UTC", 2026, 3, 1, 0))
    }

    @Test func startOfDayIsMidnightInTheCalendarsZone() {
        let c = calendar("Asia/Kolkata")
        let start = c.startOfDay(date("Asia/Kolkata", 2026, 10, 7, 15))
        #expect(start == date("Asia/Kolkata", 2026, 10, 7, 0))
    }

    @Test func aMonthsWorkDaysAddUpToItsParts() {
        let c = calendar()
        let start = c.startOfMonth(date("UTC", 2026, 10, 15))
        let end = c.startOfNextMonth(date("UTC", 2026, 10, 15))
        let middle = date("UTC", 2026, 10, 15)
        #expect(
            c.workDays(from: start, to: end) == c.workDays(from: start, to: middle) + c.workDays(from: middle, to: end))
        #expect(c.workDays(from: start, to: end) == 22)
    }
}
