import ConsumptionKit
import Foundation

extension BudgetSettings {
    private static let key = "budgetSettings"

    static func load() -> BudgetSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(BudgetSettings.self, from: data)
        else { return BudgetSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
