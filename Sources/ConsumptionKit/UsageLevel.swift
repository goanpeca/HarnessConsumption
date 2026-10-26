import Foundation

/// How worried to be about a window: drives the green, orange and red in the UI.
public enum UsageLevel: Sendable, Equatable {
    case good, watch, critical

    /// Percent left below which a window is critical whatever the pace.
    static let criticalRemaining = 10.0
    /// Percent left below which an unpaced window (no reset date) is a watch.
    static let watchRemaining = 25.0
    /// Percentage points over the even pace that turn a watch into critical.
    static let criticalOverPace = 10.0
}

extension UsageWindow {
    /// Green at or under the even pace, orange slightly over, red well over or nearly empty. Without a
    /// pace (idle windows) it falls back to the percent left.
    public func level(pace: WindowPace?) -> UsageLevel {
        if remainingPercent < UsageLevel.criticalRemaining { return .critical }
        guard let pace else { return remainingPercent < UsageLevel.watchRemaining ? .watch : .good }
        let over = pace.usedPercent - pace.targetUsedByEndOfToday
        if over > UsageLevel.criticalOverPace { return .critical }
        return pace.isOverPace ? .watch : .good
    }

    /// The level in words, so color is never the only signal.
    public func status(pace: WindowPace?) -> String {
        let level = level(pace: pace)
        if remainingPercent < UsageLevel.criticalRemaining { return "Almost out" }
        switch (level, pace == nil) {
        case (.good, true): return "Plenty left"
        case (.good, false): return "On pace"
        case (.watch, true): return "Running low"
        case (.watch, false): return "Ahead of pace"
        case (.critical, _): return "Well over pace"
        }
    }
}
