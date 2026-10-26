import ConsumptionKit
import Foundation

extension WorkSettings {
    private static let key = "workSettings"

    /// The system region, offered as the country until the user confirms their own.
    static var suggestedRegion: String? { Locale.current.region?.identifier }

    /// A fresh install starts unconfigured, with the system region suggested.
    static func load() -> WorkSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(WorkSettings.self, from: data),
            !settings.weekdays.isEmpty
        else { return .firstRun(regionCode: suggestedRegion) }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
