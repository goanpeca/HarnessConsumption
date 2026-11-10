import Foundation

/// The app's bundle identifier moved (`com.goanpeca.agentconsumption`, then
/// `com.goanpeca.harnessconsumption`, `io.github.goanpeca.harnessconsumption`, now
/// `io.github.goanpeca.harness-consumption`), and each identifier has
/// its own defaults domain. On first launch this carries the user's settings over from the newest old
/// domain that has them. It never copies the `NSStatusItem` keys: macOS had marked each old identifier's
/// menu bar item as removed, and would not show it again.
enum SettingsMigration {
    /// Newest first.
    static let oldDomains = [
        "io.github.goanpeca.harnessconsumption", "com.goanpeca.harnessconsumption", "com.goanpeca.agentconsumption",
    ]
    static let keys = ["workSettings", "budgetSettings", "refreshMinutes", "alertState"]

    /// Copies from the first of `olds` that has settings. Returns whether anything was copied.
    @discardableResult
    static func run(fromFirstOf olds: [UserDefaults?], to new: UserDefaults) -> Bool {
        olds.contains { run(from: $0, to: new) }
    }

    /// Copies the settings when `new` has none of its own yet. Returns whether anything was copied.
    @discardableResult
    static func run(from old: UserDefaults?, to new: UserDefaults) -> Bool {
        guard let old, !keys.contains(where: { new.object(forKey: $0) != nil }) else { return false }
        var copied = false
        for key in keys {
            if let value = old.object(forKey: key) {
                new.set(value, forKey: key)
                copied = true
            }
        }
        return copied
    }
}
