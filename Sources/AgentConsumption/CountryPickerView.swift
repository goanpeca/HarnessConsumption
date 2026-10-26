import ConsumptionKit
import SwiftUI

/// Which country's public holidays count as days off; shared by Settings and first-run setup.
struct CountryPicker: View {
    let store: UsageStore

    private var settings: WorkSettings { store.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Country").font(.headline)
            Picker("Country", selection: country) {
                Text("None (weekends only)").tag(String?.none)
                Divider()
                ForEach(countryOptions) { country in
                    Text(country.name).tag(Optional(country.code))
                }
            }
            .labelsHidden()
            Toggle("Treat public holidays as days off", isOn: skipHolidays)
                .disabled(settings.countryCode == nil)
            if store.holidaysMissing {
                Label(
                    "Couldn't load holidays for this country. They're ignored until it works.",
                    systemImage: "wifi.exclamationmark"
                )
                .font(.caption).foregroundStyle(.orange)
            }
        }
        .task { await store.loadCountries() }
    }

    /// The loaded list, with the current country first if the list isn't available yet.
    private var countryOptions: [Country] {
        var list = store.countries
        if let code = settings.countryCode, !list.contains(where: { $0.code == code }) {
            list.insert(Country(code: code, name: Locale.current.localizedString(forRegionCode: code) ?? code), at: 0)
        }
        return list
    }

    private var country: Binding<String?> {
        Binding(
            get: { settings.countryCode },
            set: { code in
                var new = settings
                new.countryCode = code
                store.update(new)
            })
    }

    private var skipHolidays: Binding<Bool> {
        Binding(
            get: { settings.skipHolidays },
            set: { value in
                var new = settings
                new.skipHolidays = value
                store.update(new)
            })
    }
}
