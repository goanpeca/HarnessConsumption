import Foundation
import Testing

@testable import ConsumptionKit

struct WorkSettingsTests {
    let holidays = Fixtures.holidays2026
    let bogota = WorkCalendar.colombia

    func calendar(_ settings: WorkSettings) -> WorkCalendar {
        settings.calendar(holidays: holidays, timeZone: bogota)
    }

    @Test func defaultIsMonToFriWithColombianHolidays() {
        let calendar = calendar(WorkSettings())
        #expect(calendar.workDays(from: Fixtures.bogota(10, 1), to: Fixtures.bogota(11, 1)) == 21)
    }

    @Test func noCountryOnlySkipsWeekends() {
        let calendar = calendar(WorkSettings(countryCode: nil))
        #expect(calendar.isWorkDay(Fixtures.bogota(10, 12)))  // holiday in Colombia, ignored
        #expect(!calendar.isWorkDay(Fixtures.bogota(10, 10)))  // Saturday
        #expect(calendar.workDays(from: Fixtures.bogota(10, 1), to: Fixtures.bogota(11, 1)) == 22)
    }

    @Test func holidaysCanBeCountedAsWorkDays() {
        let calendar = calendar(WorkSettings(skipHolidays: false))
        #expect(calendar.isWorkDay(Fixtures.bogota(10, 12)))
    }

    @Test func saturdaysWithoutSundaysOrHolidays() {
        let settings = WorkSettings(weekdays: WorkSettings.monToFri.union([7]))
        let calendar = calendar(settings)
        #expect(calendar.isWorkDay(Fixtures.bogota(10, 10)))  // Saturday
        #expect(!calendar.isWorkDay(Fixtures.bogota(10, 11)))  // Sunday
        #expect(!calendar.isWorkDay(Fixtures.bogota(10, 12)))  // holiday Monday
        #expect(calendar.workDays(from: Fixtures.bogota(10, 1), to: Fixtures.bogota(11, 1)) == 26)
    }

    @Test func everyDayIncludingHolidays() {
        let settings = WorkSettings(weekdays: Set(1...7), skipHolidays: false)
        let calendar = calendar(settings)
        #expect(calendar.workDays(from: Fixtures.bogota(10, 1), to: Fixtures.bogota(11, 1)) == 31)
    }

    @Test func pacingFollowsTheSettings() throws {
        // Window Oct 7 (Wed) to the reset on Oct 14; counting Saturdays adds Oct 10.
        let now = Fixtures.bogota(10, 7, 9, 30)
        let withSaturday = calendar(WorkSettings(weekdays: WorkSettings.monToFri.union([7])))
        let pace = try #require(WindowPace.compute(window: Fixtures.weekly(used: 0), calendar: withSaturday, now: now))
        #expect(pace.workDaysLeft == 5)
        #expect(pace.todayShare == 20)
    }

    @Test func settingsRoundTripThroughJSON() throws {
        let settings = WorkSettings(weekdays: [2, 7], countryCode: nil, skipHolidays: false)
        let decoded = try JSONDecoder().decode(WorkSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }
}

struct WorkSettingsSummaryTests {
    let countries = [Country(code: "CO", name: "Colombia")]

    @Test func defaultSummary() {
        #expect(WorkSettings().summary(countries: countries) == "Mon–Fri, skipping Colombia holidays")
    }

    @Test func runsAndSingleDays() {
        #expect(WorkSettings(weekdays: [2, 3, 4, 5, 6, 7]).summary(countries: countries).hasPrefix("Mon–Sat,"))
        #expect(WorkSettings(weekdays: [2, 7]).summary(countries: countries).hasPrefix("Mon, Sat,"))
        #expect(WorkSettings(weekdays: [1]).summary(countries: countries).hasPrefix("Sun,"))
        #expect(WorkSettings(weekdays: [2, 3]).summary(countries: countries).hasPrefix("Mon, Tue,"))
    }

    @Test func sundayStartsItsOwnRunAfterSaturday() {
        // Display order is Monday first, so Sat and Sun are neighbours.
        #expect(WorkSettings(weekdays: [6, 7, 1]).summary(countries: countries).hasPrefix("Fri–Sun,"))
    }

    @Test func holidayWording() {
        #expect(WorkSettings(countryCode: nil).summary() == "Mon–Fri; no holidays")
        #expect(WorkSettings(skipHolidays: false).summary(countries: countries) == "Mon–Fri; Colombia holidays counted")
        #expect(WorkSettings().summary() == "Mon–Fri, skipping CO holidays")
    }

    @Test func weekdayNames() {
        #expect(WorkSettings.weekdayName(1) == "Sun")
        #expect(WorkSettings.weekdayName(7) == "Sat")
        #expect(WorkSettings.weekdayName(0) == "?")
    }
}
