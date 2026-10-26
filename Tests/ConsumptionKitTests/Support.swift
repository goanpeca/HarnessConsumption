import Foundation

@testable import ConsumptionKit

/// A small deterministic generator (SplitMix64) so randomized tests fail the same way every run. A
/// failing case prints its seed and iteration; rerun with that seed to reproduce it.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum Randomized {
    static let zones = [
        "UTC", "America/Bogota", "America/New_York", "Europe/Berlin", "Asia/Kolkata", "Pacific/Auckland",
        "Pacific/Kiritimati", "America/Los_Angeles",
    ]
    /// 2026-01-01 00:00 UTC.
    static let epoch = Date(timeIntervalSince1970: 1_767_225_600)

    static func calendar(_ rng: inout SeededGenerator) -> WorkCalendar {
        let zone = TimeZone(identifier: zones.randomElement(using: &rng) ?? "UTC") ?? .gmt
        var weekdays = Set(Array(1...7).filter { _ in Bool.random(using: &rng) })
        if weekdays.isEmpty { weekdays = [2] }
        var holidays = Set<Day>()
        for _ in 0..<Int.random(in: 0...25, using: &rng) {
            holidays.insert(
                Day(
                    year: Int.random(in: 2026...2027, using: &rng), month: Int.random(in: 1...12, using: &rng),
                    day: Int.random(in: 1...28, using: &rng)))
        }
        return WorkCalendar(holidays: holidays, workWeekdays: weekdays, timeZone: zone)
    }

    static func date(_ rng: inout SeededGenerator, spanDays: Int = 730) -> Date {
        epoch.addingTimeInterval(Double.random(in: 0...(Double(spanDays) * 86_400), using: &rng))
    }
}
