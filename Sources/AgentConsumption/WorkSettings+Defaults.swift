import ConsumptionKit
import Foundation

extension WorkSettings {
    private static let key = "workSettings"

    /// Defaults to Mon–Fri with Colombian holidays when nothing has been saved yet.
    static func load() -> WorkSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(WorkSettings.self, from: data),
            !settings.weekdays.isEmpty
        else { return WorkSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
