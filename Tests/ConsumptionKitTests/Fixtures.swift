import Foundation

@testable import ConsumptionKit

enum Fixtures {
    /// Colombia 2026, as returned by Nager.Date.
    static let holidays2026: Set<Day> = Set(
        [
            "2026-01-01", "2026-01-12", "2026-03-23", "2026-04-02", "2026-04-03", "2026-05-01",
            "2026-05-18", "2026-06-08", "2026-06-15", "2026-06-29", "2026-07-13", "2026-07-20",
            "2026-08-07", "2026-08-17", "2026-10-12", "2026-11-02", "2026-11-16", "2026-12-08", "2026-12-25",
        ].compactMap(Day.init(iso:)))

    static let colombia = TimeZone(identifier: "America/Bogota") ?? .gmt

    static let calendar = WorkCalendar(holidays: holidays2026, timeZone: colombia)

    /// A wall-clock time in Bogotá.
    static func bogota(_ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0, year: Int = 2026) -> Date {
        calendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Weekly window resetting Wed 14 Oct 2026 08:52 Bogotá (from a real Codex response).
    static func weekly(used: Double) -> UsageWindow {
        UsageWindow(
            kind: .weekly, usedPercent: used, resetsAt: Date(timeIntervalSince1970: 1_791_985_929),
            length: 604_800)
    }
}
