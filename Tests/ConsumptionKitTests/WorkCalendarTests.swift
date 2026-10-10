import Foundation
import Testing

@testable import ConsumptionKit

struct WorkCalendarTests {
    let calendar = Fixtures.calendar

    @Test func weekendsAndHolidaysAreNotWorkDays() {
        #expect(calendar.isWorkDay(Fixtures.bogota(10, 7)))  // Wednesday
        #expect(!calendar.isWorkDay(Fixtures.bogota(10, 10)))  // Saturday
        #expect(!calendar.isWorkDay(Fixtures.bogota(10, 11)))  // Sunday
        #expect(!calendar.isWorkDay(Fixtures.bogota(10, 12)))  // Día de la Raza (Monday)
    }

    @Test func octoberHas21WorkDays() {
        #expect(calendar.workDays(from: Fixtures.bogota(10, 1), to: Fixtures.bogota(11, 1)) == 21)
    }

    @Test func workDaysUsesBogotaDatesNotUTC() {
        // 23:30 Friday in Bogotá is already Saturday in UTC; it still counts as Friday.
        let fridayNight = Fixtures.bogota(10, 9, 23, 30)
        #expect(calendar.isWorkDay(fridayNight))
        #expect(calendar.workDays(from: fridayNight, to: Fixtures.bogota(10, 13)) == 1)
    }

    @Test func dayParsesISODates() {
        #expect(Day(iso: "2026-10-12") == Day(year: 2026, month: 10, day: 12))
        #expect(Day(iso: "2026-10-12T00:00:00") == Day(year: 2026, month: 10, day: 12))
        #expect(Day(iso: "garbage") == nil)
    }

    @Test func holidayStoreParsesNagerPayload() throws {
        let json = #"[{"date":"2026-10-12","localName":"Día de la Raza"},{"date":"2026-11-02"}]"#
        let days = try HolidayStore.parse(Data(json.utf8))
        #expect(days == [Day(year: 2026, month: 10, day: 12), Day(year: 2026, month: 11, day: 2)])
    }
}
