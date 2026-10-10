import ConsumptionKit
import Foundation
import Observation
import os

struct ProviderState {
    var usage: ProviderUsage?
    var error: String?
}

/// Owns the hourly refresh: fetches both providers, rebuilds the work calendar and hands the result
/// to the alert planner.
@MainActor @Observable
final class UsageStore {
    static let refreshInterval: TimeInterval = 3600

    private(set) var states: [Provider: ProviderState] = [:]
    private(set) var calendar = WorkCalendar(holidays: [])
    private(set) var holidaysMissing = false
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    private let claude: ClaudeClient
    private let codex: CodexClient
    private let holidays: HolidayStore
    private let notifier: Notifier
    private let planner = AlertPlanner()
    private let log = Logger(subsystem: "com.goanpeca.agentconsumption", category: "store")
    private var timer: Timer?

    init(notifier: Notifier) {
        let session = URLSession(configuration: .ephemeral)
        claude = ClaudeClient(session: session)
        codex = CodexClient(session: session)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentConsumption")
        holidays = HolidayStore(countryCode: "CO", directory: support)
        self.notifier = notifier
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { await refresh() }
    }

    /// - Parameter notify: false for `--dump`, which must not post or consume alerts.
    func refresh(notify: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let now = Date()

        let year = WorkCalendar(holidays: []).calendar.component(.year, from: now)
        let (days, missing) = await holidays.holidays(years: [year, year + 1])
        calendar = WorkCalendar(holidays: days)
        holidaysMissing = missing.contains(year)

        async let claudeResult = Result { try await claude.fetch(now: now) }
        async let codexResult = Result { try await codex.fetch(now: now) }
        apply(.claude, await claudeResult)
        apply(.codex, await codexResult)
        lastRefresh = now
        guard notify else { return }

        let usages = Provider.allCases.compactMap { states[$0]?.usage }
        var alertState = loadAlertState()
        let alerts = planner.plan(usages: usages, calendar: calendar, now: now, state: &alertState)
        saveAlertState(alertState)
        for alert in alerts { notifier.post(alert) }
    }

    private func apply(_ provider: Provider, _ result: Result<ProviderUsage, Error>) {
        switch result {
        case let .success(usage):
            states[provider] = ProviderState(usage: usage, error: nil)
        case let .failure(error):
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            log.error("\(provider.rawValue, privacy: .public) failed: \(message, privacy: .public)")
            // Keep the last good reading so the menu still shows something, marked with the error.
            states[provider, default: ProviderState()].error = message
        }
    }

    // MARK: Derived values for the UI

    func pace(_ provider: Provider, _ kind: WindowKind) -> WindowPace? {
        guard let window = states[provider]?.usage?.windows.first(where: { $0.kind == kind }) else { return nil }
        return WindowPace.compute(window: window, calendar: calendar, now: .now)
    }

    func monthOutlook(_ provider: Provider) -> MonthOutlook {
        MonthOutlook.compute(calendar: calendar, now: .now, weekly: states[provider]?.usage?.weekly)
    }

    /// Plain-text report for `AgentConsumption --dump`.
    var report: String {
        var lines = ["menu bar: \(menuBarTitle)"]
        for provider in Provider.allCases {
            let state = states[provider]
            lines.append("\(provider.displayName) (\(state?.usage?.plan ?? "?"))")
            if let error = state?.error { lines.append("  error: \(error)") }
            for window in state?.usage?.windows ?? [] {
                var line = "  \(window.kind.displayName): \(Int(window.remainingPercent.rounded()))% left"
                if let reset = window.resetsAt { line += ", resets \(reset.formatted())" }
                if window.kind == .weekly, let pace = pace(provider, .weekly) {
                    line += String(
                        format: ", today %.1f%% over %d work days%@", pace.todayShare, pace.workDaysLeft,
                        pace.isOverPace ? " (OVER PACE)" : "")
                }
                lines.append(line)
            }
            let month = monthOutlook(provider)
            if let projected = month.projectedPercentLeft, let daily = month.dailyShare {
                lines.append(String(format: "  month: %.0f%% of a week left, %.1f%%/day", projected, daily))
            }
        }
        let month = monthOutlook(.claude)
        lines.append(
            "work days: \(month.workDaysLeft) of \(month.workDaysInMonth) left this month"
                + (holidaysMissing ? " (holidays unavailable)" : ""))
        return lines.joined(separator: "\n")
    }

    /// e.g. `✳︎ 62% ◎ 80%`: weekly quota left per provider.
    var menuBarTitle: String {
        let parts = Provider.allCases.map { provider -> String in
            let symbol = provider == .claude ? "✳︎" : "◎"
            guard let weekly = states[provider]?.usage?.weekly else { return "\(symbol) –" }
            let stale = states[provider]?.error != nil ? "?" : ""
            return "\(symbol) \(Int(weekly.remainingPercent.rounded()))%\(stale)"
        }
        return parts.joined(separator: "  ")
    }

    // MARK: Alert state persistence

    private static let alertStateKey = "alertState"

    private func loadAlertState() -> AlertState {
        guard let data = UserDefaults.standard.data(forKey: Self.alertStateKey),
            let state = try? JSONDecoder().decode(AlertState.self, from: data)
        else { return AlertState() }
        return state
    }

    private func saveAlertState(_ state: AlertState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.alertStateKey)
        }
    }
}

private extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = try .success(await body()) } catch { self = .failure(error) }
    }
}
