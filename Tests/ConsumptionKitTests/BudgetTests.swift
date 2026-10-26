import Foundation
import Testing

@testable import ConsumptionKit

struct BudgetTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.bogota(10, 26)
    let reset = Fixtures.bogota(11, 1, 0)
    let settings = BudgetSettings(totalUSD: 4000, codexLimitUSD: 4000)

    private func usage(_ provider: Provider, spend: SpendReading?, used: Double = 10) -> ProviderUsage {
        let window = UsageWindow(kind: .monthly, usedPercent: used, resetsAt: reset, length: 31 * 86_400)
        return ProviderUsage(provider: provider, plan: nil, windows: [window], fetchedAt: now, spend: spend)
    }

    private var claude: ProviderUsage { usage(.claude, spend: SpendReading(used: 2000, limit: 4200, unit: .usd)) }
    private var codex: ProviderUsage {
        usage(.codex, spend: SpendReading(used: 21_429, limit: 42_858, unit: .credits))
    }

    @Test func sumsBothProvidersAgainstTheSharedBudget() throws {
        let status = try #require(BudgetStatus.compute(usages: [claude, codex], settings: settings))
        #expect(status.spentByProvider[.claude] == 2000)
        #expect(abs((status.spentByProvider[.codex] ?? 0) - 2000) < 0.01)
        #expect(abs(status.spentUSD - 4000) < 0.01)
        #expect(status.remainingUSD < 0.01)
        #expect(status.window.usedPercent > 99.9)
        #expect(status.missing.isEmpty)
    }

    @Test func halfEachMeansNothingLeft() throws {
        let half = usage(.claude, spend: SpendReading(used: 2100, limit: 4200, unit: .usd))
        let status = try #require(BudgetStatus.compute(usages: [half, codex], settings: settings))
        #expect(status.window.remainingPercent < 3)
    }

    @Test func percentAndPerDayFollowTheBudget() throws {
        let light = usage(.claude, spend: SpendReading(used: 400, limit: 4200, unit: .usd))
        let status = try #require(BudgetStatus.compute(usages: [light], settings: settings))
        #expect(status.window.usedPercent == 10)
        let pace = try #require(status.pace(calendar: calendar, now: now))
        let expected = 3600 / Double(pace.workDaysLeft)
        #expect(abs(status.dollarsPerDay(pace: pace) - expected) < 0.001)
        #expect(status.missing == [.codex])
    }

    @Test func unavailableWithoutAnySpendReading() {
        #expect(BudgetStatus.compute(usages: [usage(.claude, spend: nil)], settings: settings) == nil)
    }

    @Test func offWhenBudgetIsZero() {
        #expect(BudgetStatus.compute(usages: [claude], settings: BudgetSettings(totalUSD: 0)) == nil)
    }

    @Test func overspendClampsAtZeroLeft() throws {
        let big = usage(.claude, spend: SpendReading(used: 9000, limit: 10_000, unit: .usd))
        let status = try #require(BudgetStatus.compute(usages: [big], settings: settings))
        #expect(status.remainingUSD == 0)
        #expect(status.window.remainingPercent == 0)
    }
}

struct BudgetEdgeTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.bogota(10, 26)

    private func claudeUsage(spend: SpendReading?, resetsAt: Date?, used: Double = 0) -> ProviderUsage {
        let window = UsageWindow(kind: .monthly, usedPercent: used, resetsAt: resetsAt, length: 31 * 86_400)
        return ProviderUsage(provider: .claude, plan: nil, windows: [window], fetchedAt: now, spend: spend)
    }

    @Test func settingsRoundTripThroughJSON() throws {
        let settings = BudgetSettings(totalUSD: 1234.5, codexLimitUSD: 99)
        let decoded = try JSONDecoder().decode(BudgetSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        #expect(BudgetSettings().totalUSD == 4000)
        #expect(BudgetSettings().isOn)
        #expect(!BudgetSettings(totalUSD: 0).isOn)
    }

    @Test func noMonthlyResetMeansNoPaceButStillAPercent() throws {
        let usage = claudeUsage(spend: SpendReading(used: 1000, limit: 4200, unit: .usd), resetsAt: nil)
        let status = try #require(BudgetStatus.compute(usages: [usage], settings: BudgetSettings()))
        #expect(status.window.usedPercent == 25)
        #expect(status.pace(calendar: calendar, now: now) == nil)
    }

    @Test func usesTheEarliestMonthlyReset() throws {
        let early = Fixtures.bogota(10, 31)
        let late = Fixtures.bogota(11, 15)
        let first = claudeUsage(spend: SpendReading(used: 1, limit: 2, unit: .usd), resetsAt: late)
        var second = claudeUsage(spend: SpendReading(used: 1, limit: 2, unit: .credits), resetsAt: early)
        second.provider = .codex
        let status = try #require(BudgetStatus.compute(usages: [first, second], settings: BudgetSettings()))
        #expect(status.window.resetsAt == early)
    }

    @Test func zeroLimitCreditsAreIgnoredNotDivided() {
        let zero = SpendReading(used: 5, limit: 0, unit: .credits)
        var usage = claudeUsage(spend: zero, resetsAt: nil)
        usage.provider = .codex
        #expect(BudgetStatus.compute(usages: [usage], settings: BudgetSettings()) == nil)
    }

    @Test func perDayIsAllRemainingWhenNoWorkDaysAreLeft() throws {
        let reset = Fixtures.bogota(10, 26, 0)
        let usage = claudeUsage(spend: SpendReading(used: 1000, limit: 4200, unit: .usd), resetsAt: reset)
        let status = try #require(BudgetStatus.compute(usages: [usage], settings: BudgetSettings()))
        let pace = try #require(status.pace(calendar: calendar, now: Fixtures.bogota(10, 31)))
        #expect(status.dollarsPerDay(pace: pace) == status.remainingUSD)
    }
}

struct SpendParsingTests {
    let now = Date(timeIntervalSince1970: 1_791_383_288)

    @Test func nonUSDClaudeSpendIsNotMistakenForDollars() throws {
        let json = #"{"extra_usage":{"utilization":10,"used_credits":100,"monthly_limit":1000,"currency":"EUR"}}"#
        let usage = try ClaudeUsageParser.parse(Data(json.utf8), plan: nil, now: now)
        #expect(usage.spend == nil)
        #expect(usage.monthly?.usedPercent == 10)
    }

    @Test func claudeSpendRespectsDecimalPlaces() throws {
        let json = #"""
            {"extra_usage":{"utilization":50,"used_credits":2500,"monthly_limit":5000,
                            "currency":"USD","decimal_places":0}}
            """#
        let usage = try ClaudeUsageParser.parse(Data(json.utf8), plan: nil, now: now)
        #expect(usage.spend == SpendReading(used: 2500, limit: 5000, unit: .usd))
    }

    @Test func claudeWindowsKeepNoSpendWhenExtraUsageIsAbsent() throws {
        let json = #"{"five_hour":{"utilization":1,"resets_at":null},"seven_day":null}"#
        let usage = try ClaudeUsageParser.parse(Data(json.utf8), plan: nil, now: now)
        #expect(usage.spend == nil)
    }

    @Test func codexSpendIsNilWhenAmountsAreNotNumbers() throws {
        let json = #"""
            {"rate_limit":null,"spend_control":{"individual_limit":
              {"limit":"unlimited","used":"n/a","used_percent":3,"reset_at":1793491200}}}
            """#
        let usage = try CodexUsageParser.parse(Data(json.utf8), now: now)
        #expect(usage.spend == nil)
        #expect(usage.monthly?.usedPercent == 3)
    }

    @Test func codexRateLimitWindowsCarryNoSpend() throws {
        let json = #"{"rate_limit":{"primary_window":{"used_percent":12,"limit_window_seconds":604800}}}"#
        #expect(try CodexUsageParser.parse(Data(json.utf8), now: now).spend == nil)
    }

    @Test func monthlyLengthFollowsTheCalendarMonth() {
        func length(endingAt iso: String) -> TimeInterval? {
            monthlyWindow(usedPercent: 0, resetsAt: ClaudeUsageParser.parseISODate(iso)).length
        }
        #expect(length(endingAt: "2026-11-01T00:00:00Z") == TimeInterval(31 * 86_400))
        #expect(length(endingAt: "2026-12-01T00:00:00Z") == TimeInterval(30 * 86_400))
        #expect(length(endingAt: "2026-03-01T00:00:00Z") == TimeInterval(28 * 86_400))
        #expect(length(endingAt: "2028-03-01T00:00:00Z") == TimeInterval(29 * 86_400))
        #expect(monthlyWindow(usedPercent: 0, resetsAt: nil).length == WindowKind.monthly.defaultLength)
    }

    @Test func nextMonthStartRollsOverTheYear() {
        let december = ClaudeUsageParser.parseISODate("2026-12-15T10:00:00Z") ?? .now
        #expect(
            ClaudeUsageParser.nextMonthStartUTC(after: december)
                == ClaudeUsageParser.parseISODate("2027-01-01T00:00:00Z"))
    }
}
