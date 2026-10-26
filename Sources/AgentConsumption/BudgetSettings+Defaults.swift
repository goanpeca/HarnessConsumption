import ConsumptionKit
import Foundation

extension BudgetSettings {
    private static let key = "budgetSettings"

    static func load(from defaults: UserDefaults = .standard) -> BudgetSettings {
        guard let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(BudgetSettings.self, from: data)
        else { return BudgetSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
