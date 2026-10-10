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
    private static let intervalKey = "refreshMinutes"

    private(set) var states: [Provider: ProviderState] = [:]
    private(set) var refreshInterval = RefreshInterval(
        minutes: UserDefaults.standard.object(forKey: "refreshMinutes") as? Int)
    private(set) var settings = WorkSettings.load()
    private(set) var countries: [Country] = []
    private(set) var calendar = WorkSettings().calendar(holidays: [])
    private(set) var holidaysMissing = false
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    private let claude: ClaudeClient
    private let codex: CodexClient
    private let holidays: HolidayStore
    private let notifier: Notifier
    private var loadedHolidays = Set<Day>()
    private let planner = AlertPlanner()
    private let log = Logger(subsystem: "com.goanpeca.agentconsumption", category: "store")
    private var timer: Timer?

    init(notifier: Notifier) {
        let session = URLSession(configuration: .ephemeral)
        claude = ClaudeClient(session: session)
        codex = CodexClient(session: session)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentConsumption")
        holidays = HolidayStore(directory: support)
        self.notifier = notifier
    }

    func start() {
        guard timer == nil else { return }
        scheduleTimer()
        Task { await refresh() }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: refreshInterval.seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        timer.tolerance = min(60, refreshInterval.seconds / 10)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Changes how often usage is checked; the new schedule starts now.
    func setRefreshInterval(_ interval: RefreshInterval) {
        guard interval != refreshInterval else { return }
        refreshInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: Self.intervalKey)
        if timer != nil { scheduleTimer() }
    }

    /// - Parameter notify: false for `--dump`, which must not post or consume alerts.
    func refresh(notify: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let now = Date()

        await reloadCalendar(now: now)

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

    /// Rebuilds the work calendar from the settings, fetching holidays for the chosen country.
    private func reloadCalendar(now: Date = .now) async {
        let current = settings
        var days = Set<Day>()
        var missing = false
        if current.usesHolidays, let country = current.countryCode {
            let year = calendar.calendar.component(.year, from: now)
            let result = await holidays.holidays(country: country, years: [year, year + 1])
            days = result.days
            missing = result.missingYears.contains(year)
        }
        // Settings may have changed while holidays were loading; the newer call will rebuild.
        guard current == settings else { return }
        loadedHolidays = days
        holidaysMissing = missing
        calendar = current.calendar(holidays: days)
    }

    func loadCountries() async {
        guard countries.isEmpty, let list = await holidays.countries() else { return }
        countries = list
    }

    /// Applies new settings: the calendar updates at once, holidays follow when they load.
    func update(_ new: WorkSettings) {
        guard new != settings, !new.weekdays.isEmpty else { return }
        settings = new
        new.save()
        calendar = new.calendar(holidays: new.countryCode == nil ? [] : loadedHolidays)
        Task { await reloadCalendar() }
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
            "counted days: \(month.workDaysLeft) of \(month.workDaysInMonth) left this month "
                + "(\(settings.summary(countries: countries)))"
                + (holidaysMissing ? " (holidays unavailable)" : ""))
        return lines.joined(separator: "\n")
    }

    /// e.g. `✳︎ 62% ◎ 80%`: weekly (or monthly spend) quota left per provider.
    var menuBarTitle: String {
        let parts = Provider.allCases.map { provider -> String in
            let symbol = provider == .claude ? "✳︎" : "◎"
            guard let window = states[provider]?.usage?.headline else { return "\(symbol) –" }
            let stale = states[provider]?.error != nil ? "?" : ""
            return "\(symbol) \(Int(window.remainingPercent.rounded()))%\(stale)"
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
