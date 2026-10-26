import AppKit
import ConsumptionKit
import SwiftUI

extension UsageLevel {
    /// The green, orange and red of System Settings > Appearance > Color. Color is never the only
    /// signal; each level also has its own symbol and a status word.
    var color: Color {
        switch self {
        case .good: Color(nsColor: .accent("controlAccentGreenColor", fallback: .systemGreen))
        case .watch: Color(nsColor: .accent("controlAccentOrangeColor", fallback: .systemOrange))
        case .critical: Color(nsColor: .accent("controlAccentRedColor", fallback: .systemRed))
        }
    }

    var symbol: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .watch: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }
}

extension NSColor {
    /// AppKit's per-hue accent colors are what the picker shows but aren't in the public Swift API, so
    /// they are looked up by selector, with a public system color as the fallback.
    fileprivate static func accent(_ name: String, fallback: NSColor) -> NSColor {
        let selector = Selector(name)
        guard responds(to: selector), let color = perform(selector)?.takeUnretainedValue() as? NSColor else {
            return fallback
        }
        return color
    }
}
