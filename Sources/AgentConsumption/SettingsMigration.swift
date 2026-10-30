import Foundation

/// The app was renamed and its bundle identifier moved from `com.goanpeca.agentconsumption` to
/// `com.goanpeca.harnessconsumption`, which gives it a new defaults domain. On first launch this carries
/// the user's settings over. It never copies the `NSStatusItem` keys: macOS had marked the old
/// identifier's menu bar item as removed and quit the app at every launch because of it.
enum SettingsMigration {
    static let oldDomain = "com.goanpeca.agentconsumption"
    static let keys = ["workSettings", "budgetSettings", "refreshMinutes", "alertState"]

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
