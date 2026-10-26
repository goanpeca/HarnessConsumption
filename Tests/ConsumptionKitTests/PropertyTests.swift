import Foundation
import Testing

@testable import ConsumptionKit

/// Invariants that must hold for any input, checked on seeded random cases. A failure names the seed and
/// iteration, so `SeededGenerator(seed:)` reproduces it exactly.
struct PropertyTests {
    private static let rounds = 400

    // MARK: pacing

    @Test func paceSharesAlwaysAddUpToWhatRemains() {
        var rng = SeededGenerator(seed: 0xA11CE)
        for i in 0..<Self.rounds {
            let calendar = Randomized.calendar(&rng)
            let now = Randomized.date(&rng)
            let lengths: [Double] = [5 * 3600, 86_400, 7 * 86_400, 30 * 86_400, 31 * 86_400]
            let length = lengths.randomElement(using: &rng) ?? 86_400
            let reset = now.addingTimeInterval(Double.random(in: -length...length, using: &rng))
            let used = Double.random(in: 0...100, using: &rng)
            let window = UsageWindow(kind: .weekly, usedPercent: used, resetsAt: reset, length: length)
            guard let pace = WindowPace.compute(window: window, calendar: calendar, now: now) else {
                Issue.record("no pace for a window with a reset (round \(i))")
                continue
            }
            let tag = "seed A11CE round \(i)"
            #expect(pace.elapsedWorkDays >= 0 && pace.workDaysLeft >= 0, "\(tag)")
            #expect(pace.totalWorkDays == pace.elapsedWorkDays + pace.workDaysLeft, "\(tag)")
            #expect(pace.todayShare >= 0, "\(tag)")
            let perDay = pace.todayShare * Double(max(pace.workDaysLeft, 1))
            #expect(abs(perDay - window.remainingPercent) < 1e-9, "\(tag)")
            #expect((0...100).contains(pace.targetUsedByEndOfToday), "\(tag) target \(pace.targetUsedByEndOfToday)")
            #expect(pace.isOverPace == (pace.usedPercent > pace.targetUsedByEndOfToday + 0.5), "\(tag)")
        }
    }

    @Test func aWindowWithoutAResetHasNoPace() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<50 {
            let window = UsageWindow(kind: .weekly, usedPercent: Double.random(in: 0...100, using: &rng), resetsAt: nil)
            #expect(WindowPace.compute(window: window, calendar: Randomized.calendar(&rng), now: .now) == nil)
        }
    }

    // MARK: the calendar

    @Test func workDaysAreAdditiveAcrossAnySplitPoint() {
        var rng = SeededGenerator(seed: 0xCA1)
        for i in 0..<Self.rounds {
            let calendar = Randomized.calendar(&rng)
            let a = Randomized.date(&rng)
            let b = a.addingTimeInterval(Double.random(in: 0...(120 * 86_400), using: &rng))
            let c = b.addingTimeInterval(Double.random(in: 0...(120 * 86_400), using: &rng))
            #expect(
                calendar.workDays(from: a, to: c) == calendar.workDays(from: a, to: b)
                    + calendar.workDays(from: b, to: c),
                "seed CA1 round \(i) zone \(calendar.calendar.timeZone.identifier)")
            #expect(calendar.workDays(from: a, to: a) == 0)
            #expect(calendar.workDays(from: c, to: a) == 0 || a == c)
        }
    }

    @Test func everyDayCountsWhenAllWeekdaysCountAndThereAreNoHolidays() {
        var rng = SeededGenerator(seed: 0xDA75)
        for i in 0..<Self.rounds {
            let zone = TimeZone(identifier: Randomized.zones.randomElement(using: &rng) ?? "UTC") ?? .gmt
            let calendar = WorkCalendar(holidays: [], workWeekdays: Set(1...7), timeZone: zone)
            let start = Randomized.date(&rng)
            let n = Int.random(in: 0...200, using: &rng)
            let end = calendar.calendar.date(byAdding: .day, value: n, to: start) ?? start
            #expect(calendar.workDays(from: start, to: end) == n, "seed DA75 round \(i) zone \(zone.identifier) n \(n)")
        }
    }

    @Test func aMonthNeverHasMoreWorkDaysThanDays() {
        var rng = SeededGenerator(seed: 0x30)
        for i in 0..<200 {
            let calendar = Randomized.calendar(&rng)
            let now = Randomized.date(&rng)
            let start = calendar.startOfMonth(now)
            let end = calendar.startOfNextMonth(now)
            let count = calendar.workDays(from: start, to: end)
            #expect((0...31).contains(count), "seed 30 round \(i)")
            #expect(start <= now && now < end)
        }
    }

    @Test func holidaysOnlyEverRemoveWorkDays() {
        var rng = SeededGenerator(seed: 0x401)
        for i in 0..<200 {
            let with = Randomized.calendar(&rng)
            let without = WorkCalendar(holidays: [], workWeekdays: with.workWeekdays, timeZone: with.calendar.timeZone)
            let start = Randomized.date(&rng)
            let end = start.addingTimeInterval(Double.random(in: 0...(365 * 86_400), using: &rng))
            #expect(
                with.workDays(from: start, to: end) <= without.workDays(from: start, to: end), "seed 401 round \(i)")
        }
    }

    @Test func dayDescriptionsRoundTripForEveryRealDate() {
        var rng = SeededGenerator(seed: 0xD0)
        for _ in 0..<Self.rounds {
            let day = Day(
                year: Int.random(in: 1990...2100, using: &rng), month: Int.random(in: 1...12, using: &rng),
                day: Int.random(in: 1...28, using: &rng))
            #expect(Day(iso: day.description) == day)
        }
    }

    // MARK: levels and budgets

    private func rank(_ level: UsageLevel) -> Int {
        switch level {
        case .good: 0
        case .watch: 1
        case .critical: 2
        }
    }

    @Test func spendingMoreNeverImprovesTheLevel() {
        var rng = SeededGenerator(seed: 0x1E7E1)
        for i in 0..<Self.rounds {
            let calendar = Randomized.calendar(&rng)
            let now = Randomized.date(&rng)
            let reset = now.addingTimeInterval(Double.random(in: 3_600...(14 * 86_400), using: &rng))
            let low = Double.random(in: 0...100, using: &rng)
            let high = Double.random(in: low...100, using: &rng)
            func level(_ used: Double) -> UsageLevel {
                let window = UsageWindow(kind: .weekly, usedPercent: used, resetsAt: reset, length: 7 * 86_400)
                return window.level(pace: WindowPace.compute(window: window, calendar: calendar, now: now))
            }
            #expect(rank(level(low)) <= rank(level(high)), "seed 1E7E1 round \(i): \(low) vs \(high)")
        }
    }

    @Test func budgetsStayWithinTheirBoundsWhateverIsSpent() {
        var rng = SeededGenerator(seed: 0xB0D6)
        for i in 0..<Self.rounds {
            let settings = BudgetSettings(
                totalUSD: Double.random(in: 1...10_000, using: &rng),
                claudeUSD: Double.random(in: 1...10_000, using: &rng),
                codexLimitUSD: Double.random(in: 1...10_000, using: &rng), isShared: Bool.random(using: &rng))
            let usages = Provider.allCases.compactMap { provider -> ProviderUsage? in
                guard Bool.random(using: &rng) || provider == .claude else { return nil }
                let limit = Double.random(in: 1...50_000, using: &rng)
                let spend = SpendReading(
                    used: Double.random(in: 0...(limit * 2), using: &rng), limit: limit,
                    unit: provider == .claude ? .usd : .credits)
                let window = UsageWindow(
                    kind: .monthly, usedPercent: 0, resetsAt: Randomized.epoch.addingTimeInterval(1e6))
                return ProviderUsage(provider: provider, plan: nil, windows: [window], fetchedAt: .now, spend: spend)
            }
            let pools = BudgetStatus.pools(usages: usages, settings: settings)
            for pool in pools {
                let tag = "seed B0D6 round \(i) \(pool.title)"
                #expect((0...100).contains(pool.window.usedPercent), "\(tag)")
                #expect(pool.remainingUSD >= 0 && pool.remainingUSD <= pool.totalUSD, "\(tag)")
                #expect(abs(pool.window.remainingPercent + pool.window.usedPercent - 100) < 1e-9, "\(tag)")
                #expect(pool.spentUSD >= 0, "\(tag)")
                #expect(Set(pool.missing).isDisjoint(with: pool.spentByProvider.keys), "\(tag)")
            }
            #expect(pools.count <= (settings.isShared ? 1 : 2))
        }
    }

    @Test func aSharedPoolSpendsExactlyWhatItsProvidersSpent() {
        var rng = SeededGenerator(seed: 0x5A)
        for i in 0..<200 {
            let a = Double.random(in: 0...3_000, using: &rng)
            let credits = Double.random(in: 0...20_000, using: &rng)
            let usages = [
                ProviderUsage(
                    provider: .claude, plan: nil, windows: [], fetchedAt: .now,
                    spend: SpendReading(used: a, limit: 4_200, unit: .usd)),
                ProviderUsage(
                    provider: .codex, plan: nil, windows: [], fetchedAt: .now,
                    spend: SpendReading(used: credits, limit: 40_000, unit: .credits)),
            ]
            let settings = BudgetSettings(totalUSD: 4_000, codexLimitUSD: 4_000)
            guard let pool = BudgetStatus.compute(usages: usages, settings: settings) else {
                Issue.record("no pool (round \(i))")
                continue
            }
            let expected = a + credits / 40_000 * 4_000
            #expect(abs(pool.spentUSD - expected) < 1e-6, "seed 5A round \(i)")
        }
    }
}
