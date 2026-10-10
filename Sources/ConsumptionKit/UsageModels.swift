import Foundation

public enum Provider: String, Codable, Sendable, CaseIterable, Identifiable {
    case claude, codex

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

/// Which rate-limit window a reading belongs to.
public enum WindowKind: String, Codable, Sendable {
    /// The rolling 5-hour session window.
    case session
    /// The 7-day window.
    case weekly
    /// A monthly spend limit, reported instead of rate-limit windows on some plans.
    case monthly

    public var displayName: String {
        switch self {
        case .session: "5-hour"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    /// Classifies a window by its length; anything over a day counts as weekly.
    public init(length: TimeInterval) {
        self = length > 86_400 ? .weekly : .session
    }

    public var defaultLength: TimeInterval {
        switch self {
        case .session: 5 * 3600
        case .weekly: 7 * 86_400
        case .monthly: 30 * 86_400
        }
    }
}

public struct UsageWindow: Codable, Sendable, Equatable {
    public var kind: WindowKind
    /// 0...100
    public var usedPercent: Double
    public var resetsAt: Date?
    public var length: TimeInterval

    public init(kind: WindowKind, usedPercent: Double, resetsAt: Date?, length: TimeInterval? = nil) {
        self.kind = kind
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
        self.length = length ?? kind.defaultLength
    }

    public var remainingPercent: Double { 100 - usedPercent }
}

public struct ProviderUsage: Codable, Sendable, Equatable {
    public var provider: Provider
    public var plan: String?
    public var windows: [UsageWindow]
    public var fetchedAt: Date

    public init(provider: Provider, plan: String?, windows: [UsageWindow], fetchedAt: Date) {
        self.provider = provider
        self.plan = plan
        self.windows = windows
        self.fetchedAt = fetchedAt
    }

    public var weekly: UsageWindow? { windows.first { $0.kind == .weekly } }
    public var session: UsageWindow? { windows.first { $0.kind == .session } }
    public var monthly: UsageWindow? { windows.first { $0.kind == .monthly } }

    /// The window the menu bar shows: weekly when there is one, else the monthly spend limit.
    public var headline: UsageWindow? { weekly ?? monthly }
}
