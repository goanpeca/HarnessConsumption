import ConsumptionKit
import SwiftUI

/// Which days count as available, shown in place of the usage panel.
struct SettingsView: View {
    let store: UsageStore
    let done: () -> Void

    private var settings: WorkSettings { store.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.title3.bold())

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

            VStack(alignment: .leading, spacing: 6) {
                Text("Days that count").font(.headline)
                HStack(spacing: 6) {
                    ForEach(WorkSettings.displayOrder, id: \.self) { weekday in
                        DayToggle(
                            name: WorkSettings.weekdayNames[weekday]!,
                            isOn: weekdayBinding(weekday),
                            isLast: settings.weekdays == [weekday])
                    }
                }
                Text("Quota is spread over these days; the rest are treated as days off.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text(settings.summary(countries: store.countries))
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("Reset") { store.update(WorkSettings()) }
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction)
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

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { settings.weekdays.contains(weekday) },
            set: { on in
                var new = settings
                if on { new.weekdays.insert(weekday) } else { new.weekdays.remove(weekday) }
                store.update(new)
            })
    }
}

private struct DayToggle: View {
    let name: String
    @Binding var isOn: Bool
    /// The only counted day can't be turned off.
    let isLast: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(name)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15), in: .rect(cornerRadius: 6))
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(isOn && isLast)
    }
}
