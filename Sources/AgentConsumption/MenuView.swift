import ConsumptionKit
import SwiftUI

struct MenuView: View {
    let store: UsageStore
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(store: store) { showSettings = false }
            } else {
                usage
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var usage: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Provider.allCases) { provider in
                ProviderSection(store: store, provider: provider)
                Divider()
            }
            MonthSection(store: store)
            Divider()
            footer
        }
    }

    private var footer: some View {
        HStack {
            if let last = store.lastRefresh {
                Text("Updated \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(store.isRefreshing ? "Refreshing…" : "Refresh") {
                Task { await store.refresh() }
            }
            .disabled(store.isRefreshing)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

private struct ProviderSection: View {
    let store: UsageStore
    let provider: Provider

    var body: some View {
        let state = store.states[provider]
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(provider.displayName).font(.headline)
                if let plan = state?.usage?.plan {
                    Text(plan.capitalized).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let error = state?.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let usage = state?.usage {
                ForEach(usage.windows, id: \.kind) { window in
                    WindowRow(window: window, pace: store.pace(provider, window.kind))
                }
            } else if state == nil {
                ProgressView().controlSize(.small)
            }
        }
    }
}

private struct WindowRow: View {
    let window: UsageWindow
    let pace: WindowPace?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.kind.displayName)
                Spacer()
                Text("\(Int(window.remainingPercent.rounded()))% left").monospacedDigit()
            }
            .font(.subheadline)
            ProgressView(value: window.usedPercent, total: 100)
                .tint(tint)
            HStack {
                if let reset = window.resetsAt {
                    Text("Resets \(reset.formatted(.relative(presentation: .named)))")
                } else {
                    Text("No active window")
                }
                Spacer()
                if window.kind == .weekly, let pace {
                    Text("Today: \(percent(pace.todayShare)) · \(days(pace.workDaysLeft)) left")
                        .foregroundStyle(pace.isOverPace ? .orange : .secondary)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tint: Color {
        if window.remainingPercent < 10 { return .red }
        if window.kind == .weekly, pace?.isOverPace == true { return .orange }
        return .accentColor
    }
}

private struct MonthSection: View {
    let store: UsageStore

    var body: some View {
        let outlook = store.monthOutlook(.claude)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Date.now.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Text("\(outlook.workDaysLeft) of \(days(outlook.workDaysInMonth)) left")
                    .font(.subheadline).monospacedDigit()
            }
            ForEach(Provider.allCases) { provider in
                let outlook = store.monthOutlook(provider)
                if let projected = outlook.projectedPercentLeft, let daily = outlook.dailyShare {
                    Text(
                        "\(provider.displayName): \(weeks(projected)) of quota left this month · "
                            + "\(percent(daily))/day"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(store.settings.summary(countries: store.countries))
                .font(.caption2).foregroundStyle(.tertiary)
            if store.holidaysMissing {
                Label(
                    "Couldn't load holidays; counting without them.",
                    systemImage: "calendar.badge.exclamationmark"
                )
                .font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

private func percent(_ value: Double) -> String {
    value < 10 ? String(format: "%.1f%%", value) : String(format: "%.0f%%", value)
}

private func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }

/// 325% of one weekly window reads as "3.3 weeks".
private func weeks(_ percent: Double) -> String {
    let value = percent / 100
    return value == 1 ? "1 week" : String(format: "%.1f weeks", value)
}
