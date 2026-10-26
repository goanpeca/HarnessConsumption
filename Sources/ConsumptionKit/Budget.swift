import Foundation

/// Monthly budgets in USD. Either one pool the providers share, or one budget per provider; each
/// provider also reports its own limit, which is not necessarily the budget you set.
public struct BudgetSettings: Codable, Sendable, Equatable {
    /// True when Claude and Codex draw from one pool (`totalUSD`); false for a budget each.
    public var isShared: Bool
    /// The shared pool.
    public var totalUSD: Double
    /// Claude's own budget when not shared.
    public var claudeUSD: Double
    /// What Codex's limit is worth in USD when fully used (its API reports credits only). When not shared
    /// it is also Codex's own budget.
    public var codexLimitUSD: Double

    public init(
        totalUSD: Double = 4000, claudeUSD: Double = 4000, codexLimitUSD: Double = 4000, isShared: Bool = true
    ) {
        self.totalUSD = totalUSD
        self.claudeUSD = claudeUSD
        self.codexLimitUSD = codexLimitUSD
        self.isShared = isShared
    }

    /// Settings saved by earlier versions lack the newer keys; they get the defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalUSD = try container.decode(Double.self, forKey: .totalUSD)
        codexLimitUSD = try container.decode(Double.self, forKey: .codexLimitUSD)
        claudeUSD = try container.decodeIfPresent(Double.self, forKey: .claudeUSD) ?? 4000
        isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared) ?? true
    }

    func budget(for provider: Provider) -> Double {
        switch provider {
        case .claude: claudeUSD
        case .codex: codexLimitUSD
        }
    }
}

/// What the providers behind one budget have spent this month.
public struct BudgetStatus: Sendable, Equatable {
    public var title: String
    public var providers: [Provider]
    public var totalUSD: Double
    public var spentByProvider: [Provider: Double]
    /// Providers with no spend reading, so the total may be an undercount.
    public var missing: [Provider]
    /// The budget as a monthly window, so pacing and levels work like any other window.
    public var window: UsageWindow

    public var spentUSD: Double { spentByProvider.values.reduce(0, +) }
    public var remainingUSD: Double { max(totalUSD - spentUSD, 0) }

    /// The shared budget, or nil when it isn't shared, is zero, or no provider reports spend.
    public static func compute(usages: [ProviderUsage], settings: BudgetSettings) -> Self? {
        guard settings.isShared else { return nil }
        return make("Shared budget", Provider.allCases, total: settings.totalUSD, usages, settings)
    }

    /// The budgets to show: one shared pool, or one per provider that has a spend reading.
    public static func pools(usages: [ProviderUsage], settings: BudgetSettings) -> [Self] {
        if settings.isShared { return compute(usages: usages, settings: settings).map { [$0] } ?? [] }
        return Provider.allCases.compactMap {
            make("\($0.displayName) budget", [$0], total: settings.budget(for: $0), usages, settings)
        }
    }

    private static func make(
        _ title: String, _ providers: [Provider], total: Double, _ usages: [ProviderUsage],
        _ settings: BudgetSettings
    ) -> Self? {
        guard total > 0 else { return nil }
        let own = usages.filter { providers.contains($0.provider) }
        var spent: [Provider: Double] = [:]
        for usage in own {
            if let dollars = usage.spend.flatMap({ usd($0, settings: settings) }) { spent[usage.provider] = dollars }
        }
        guard !spent.isEmpty else { return nil }
        let monthly = own.flatMap(\.windows).filter { $0.kind == .monthly && $0.resetsAt != nil }
            .min { ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture) }
        let used = spent.values.reduce(0, +)
        return Self(
            title: title, providers: providers, totalUSD: total, spentByProvider: spent,
            missing: providers.filter { spent[$0] == nil },
            window: UsageWindow(
                kind: .monthly, usedPercent: used / total * 100, resetsAt: monthly?.resetsAt,
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
