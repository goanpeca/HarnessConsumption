import ConsumptionKit
import Foundation

extension WorkSettings {
    private static let key = "workSettings"

    /// The system region, offered as the country until the user confirms their own.
    static var suggestedRegion: String? { Locale.current.region?.identifier }

    /// A fresh install starts unconfigured, with the system region suggested.
    static func load(from defaults: UserDefaults = .standard) -> WorkSettings {
        guard let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(WorkSettings.self, from: data),
            !settings.weekdays.isEmpty
        else { return .firstRun(regionCode: suggestedRegion) }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
