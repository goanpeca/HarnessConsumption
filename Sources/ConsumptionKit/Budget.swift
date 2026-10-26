import Foundation

/// One budget shared by every provider, in USD per month. The providers each show their own limit as
/// 100%, but together they draw from the same pool.
public struct BudgetSettings: Codable, Sendable, Equatable {
    /// 0 turns the shared budget off.
    public var totalUSD: Double
    /// What a credit-based limit (Codex) is worth in USD when fully used; the API reports credits only.
    public var codexLimitUSD: Double

    public init(totalUSD: Double = 4000, codexLimitUSD: Double = 4000) {
        self.totalUSD = totalUSD
        self.codexLimitUSD = codexLimitUSD
    }

    public var isOn: Bool { totalUSD > 0 }
}

/// What every provider has spent this month, against the shared budget.
public struct BudgetStatus: Sendable, Equatable {
    public var totalUSD: Double
    public var spentByProvider: [Provider: Double]
    /// Providers with no spend reading, so the total may be an undercount.
    public var missing: [Provider]
    /// The shared budget as a monthly window, so pacing and levels work like any other window.
    public var window: UsageWindow

    public var spentUSD: Double { spentByProvider.values.reduce(0, +) }
    public var remainingUSD: Double { max(totalUSD - spentUSD, 0) }

    public static func compute(usages: [ProviderUsage], settings: BudgetSettings) -> Self? {
        guard settings.isOn else { return nil }
        var spent: [Provider: Double] = [:]
        for usage in usages {
            if let dollars = usage.spend.flatMap({ usd($0, settings: settings) }) {
                spent[usage.provider] = dollars
            }
        }
        guard !spent.isEmpty else { return nil }
        let monthly = usages.flatMap(\.windows).filter { $0.kind == .monthly && $0.resetsAt != nil }
            .min { ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture) }
        let total = spent.values.reduce(0, +)
        return Self(
            totalUSD: settings.totalUSD, spentByProvider: spent,
            missing: Provider.allCases.filter { spent[$0] == nil },
            window: UsageWindow(
                kind: .monthly, usedPercent: total / settings.totalUSD * 100, resetsAt: monthly?.resetsAt,
                length: monthly?.length))
    }

    private static func usd(_ reading: SpendReading, settings: BudgetSettings) -> Double? {
        switch reading.unit {
        case .usd: reading.used
        case .credits: reading.limit > 0 ? reading.used / reading.limit * settings.codexLimitUSD : nil
        }
    }

    public func pace(calendar: WorkCalendar, now: Date) -> WindowPace? {
        WindowPace.compute(window: window, calendar: calendar, now: now)
    }

    /// Dollars left divided by the work days left (all of it when none are left).
    public func dollarsPerDay(pace: WindowPace) -> Double {
        remainingUSD / Double(max(pace.workDaysLeft, 1))
    }
}
