import Foundation

/// How often usage is checked. Capped below at 5 minutes: the endpoints aren't public.
public enum RefreshInterval: Int, CaseIterable, Sendable, Identifiable {
    case minutes5 = 5
    case minutes15 = 15
    case minutes30 = 30
    case hour1 = 60
    case hours2 = 120

    public static let `default` = Self.hour1

    public var id: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    public var label: String {
        switch self {
        case .minutes5, .minutes15, .minutes30: "\(rawValue) minutes"
        case .hour1: "1 hour"
        case .hours2: "2 hours"
        }
    }

    /// Unknown stored values (e.g. from a future version) fall back to the default.
    public init(minutes: Int?) {
        self = minutes.flatMap(Self.init(rawValue:)) ?? .default
    }
}
