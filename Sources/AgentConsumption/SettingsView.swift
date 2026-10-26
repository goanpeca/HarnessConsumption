import ConsumptionKit
import SwiftUI

/// Which days count as available, shown in place of the usage panel.
struct SettingsView: View {
    let store: UsageStore
    @State private var opensAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    private var settings: WorkSettings { store.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                            name: WorkSettings.weekdayName(weekday),
                            isOn: weekdayBinding(weekday),
                            isLast: settings.weekdays == [weekday])
                    }
                }
                Text("Quota is spread over these days; the rest are treated as days off.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Shared budget").font(.headline)
                MoneyField(title: "Per month (USD)", value: budgetTotal)
                MoneyField(title: "Codex limit is worth (USD)", value: codexLimit)
                Text(
                    "One pool for Claude and Codex together; 0 turns it off. Codex reports credits, so this is what its limit is worth in dollars."
                )
                .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Check usage").font(.headline)
                Picker("Check usage", selection: interval) {
                    ForEach(RefreshInterval.allCases) { Text("Every \($0.label)").tag($0) }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Open at login", isOn: loginBinding)
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.orange)
                } else if LaunchAtLogin.needsApproval {
                    Text("Approve Agent Consumption in System Settings > General > Login Items.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Text(settings.summary(countries: store.countries))
                .font(.caption).foregroundStyle(.secondary)

            Button("Reset to defaults") {
                store.update(WorkSettings())
                store.setRefreshInterval(.default)
            }
        }
        .padding(.top, 4)
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

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { opensAtLogin },
            set: { value in
                do {
                    try LaunchAtLogin.set(value)
                    loginError = nil
                } catch {
                    loginError = "Couldn't change login item: \(error.localizedDescription)"
                }
                opensAtLogin = LaunchAtLogin.isEnabled
            })
    }

    private var budgetTotal: Binding<Double> {
        Binding(
            get: { store.budget.totalUSD },
            set: { value in
                var new = store.budget
                new.totalUSD = value
                store.updateBudget(new)
            })
    }

    private var codexLimit: Binding<Double> {
        Binding(
            get: { store.budget.codexLimitUSD },
            set: { value in
                var new = store.budget
                new.codexLimitUSD = value
                store.updateBudget(new)
            })
    }

    private var interval: Binding<RefreshInterval> {
        Binding(get: { store.refreshInterval }, set: { store.setRefreshInterval($0) })
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

/// A labeled dollar amount that commits on Return or when focus leaves.
private struct MoneyField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .textFieldStyle(.roundedBorder)
        }
    }
}
