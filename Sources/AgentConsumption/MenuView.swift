import ConsumptionKit
import SwiftUI

/// Container: a pane switch above the active pane, with a shared footer. Both panes have a fixed
/// height so the window never resizes after it opens (a resize leaves it hanging below the menu bar).
struct MenuView: View {
    let store: UsageStore
    @State private var pane: Pane = .usage

    private static let paneHeight: CGFloat = 400

    enum Pane: String, CaseIterable, Identifiable {
        case usage = "Usage"
        case settings = "Settings"
        case setup = "Setup"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 8) {
            if store.settings.isConfigured {
                Picker("", selection: $pane) {
                    ForEach(Pane.allCases.filter { $0 != .setup }) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding([.top, .horizontal], 14)
            }

            switch store.settings.isConfigured ? pane : .setup {
            case .usage:
                ScrollView { usage.padding(.horizontal, 14).padding(.vertical, 6) }
                    .frame(height: Self.paneHeight)
            case .setup:
                ScrollView { SetupView(store: store).padding(.horizontal, 14).padding(.vertical, 14) }
                    .frame(height: Self.paneHeight)
            case .settings:
                ScrollView { SettingsView(store: store).padding(.horizontal, 14).padding(.vertical, 6) }
                    .frame(height: Self.paneHeight)
            }

            Divider()
            footer.buttonStyle(.bordered).controlSize(.small).padding([.bottom, .horizontal], 14)
        }
        .frame(width: 360)
        .pinnedBelowMenuBar()
        // Always open on the usage pane, not wherever it was last left.
        .onAppear { pane = .usage }
        .onExitCommand { NSApp.keyWindow?.close() }
    }

    private var usage: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(store.budgetPools, id: \.title) { pool in
                BudgetSection(store: store, status: pool)
                Divider()
            }
            ForEach(Provider.allCases) { provider in
                ProviderSection(store: store, provider: provider)
                Divider()
            }
            MonthSection(store: store)
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
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

private struct ProviderSection: View {
    let store: UsageStore
    let provider: Provider

    var body: some View {
        let state = store.states[provider]
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: provider == .claude ? "asterisk" : "terminal")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(.quaternary, in: .circle)
                Text(provider.displayName).font(.headline)
                if let plan = state?.usage?.plan {
                    Text(plan.capitalized)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: .capsule)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProviderSpendLine(store: store, provider: provider)
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
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.kind.displayName).font(.subheadline)
                Spacer()
                Text("\(Int(window.remainingPercent.rounded()))%")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("left").font(.subheadline).foregroundStyle(.secondary)
            }
            UsageBar(
                fraction: window.usedPercent / 100, tint: level.color,
                marker: pace.map { $0.targetUsedByEndOfToday / 100 })
            HStack {
                Label {
                    Text(window.status(pace: pace)).foregroundStyle(.primary)
                } icon: {
                    Image(systemName: level.symbol).foregroundStyle(level.color)
                }
                .labelStyle(.titleAndIcon)
                Text("· " + resetText)
                Spacer()
                if window.kind != .session, let pace {
                    Text("Today \(percent(pace.todayShare)) · \(days(pace.workDaysLeft)) left")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.kind.displayName) limit")
        .accessibilityValue(spokenSummary)
    }

    private var resetText: String {
        window.resetsAt.map { "Resets \($0.formatted(.relative(presentation: .named)))" } ?? "No active window"
    }

    private var spokenSummary: String {
        var parts = [
            "\(Int(window.remainingPercent.rounded())) percent left", window.status(pace: pace), resetText,
        ]
        if window.kind != .session, let pace {
            parts.append("Today \(percent(pace.todayShare)) of the limit, \(days(pace.workDaysLeft)) left")
        }
        return parts.joined(separator: ". ")
    }

    private var level: UsageLevel { window.level(pace: pace) }
}

/// A slim capsule bar showing how much of a window is used; matches system progress styling.
struct UsageBar: View {
    let fraction: Double
    let tint: Color
    /// Where an even pace would have the bar by the end of today.
    var marker: Double?

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(tint)
                        .frame(width: max(6, proxy.size.width * min(max(fraction, 0), 1)))
                    if let marker {
                        Capsule().fill(.primary)
                            .frame(width: 2, height: 12)
                            .offset(x: proxy.size.width * min(max(marker, 0), 1) - 1, y: -3)
                    }
                }
            }
            .accessibilityHidden(true)
            .padding(.vertical, marker == nil ? 0 : 3)
    }
}

private struct MonthSection: View {
    let store: UsageStore

    var body: some View {
        let outlook = store.monthOutlook(.claude)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Date.now.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Text("\(outlook.workDaysLeft) of \(days(outlook.workDaysInMonth)) left")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            ForEach(Provider.allCases) { provider in
                let outlook = store.monthOutlook(provider)
                if let projected = outlook.projectedPercentLeft, let daily = outlook.dailyShare {
                    HStack(alignment: .firstTextBaseline) {
                        Text(provider.displayName).font(.subheadline)
                        Spacer()
                        Text("\(weeks(projected)) of quota").font(.subheadline)
                        Text("· \(percent(daily))/day").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                }
            }
            Text(store.settings.summary(countries: store.countries))
                .font(.caption).foregroundStyle(.tertiary)
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

func percent(_ value: Double) -> String {
    value < 10 ? String(format: "%.1f%%", value) : String(format: "%.0f%%", value)
}

func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }

/// 325% of one weekly window reads as "3.3 weeks".
private func weeks(_ percent: Double) -> String {
    let value = percent / 100
    return value == 1 ? "1 week" : String(format: "%.1f weeks", value)
}
