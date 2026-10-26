import ConsumptionKit
import Foundation
import Observation
import os

typealias UsageFetch = @Sendable (Date) async throws -> ProviderUsage

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
    private(set) var refreshInterval: RefreshInterval
    private(set) var settings: WorkSettings
    private(set) var budget: BudgetSettings
    private(set) var countries: [Country] = []
    private(set) var calendar = WorkSettings().calendar(holidays: [])
    private(set) var holidaysMissing = false
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    private let fetchers: [Provider: UsageFetch]
    private let holidays: HolidayStore
    private let notifier: any AlertDelivering
    private let defaults: UserDefaults
    private var loadedHolidays = Set<Day>()
    private let planner = AlertPlanner()
    private let log = Logger(subsystem: "com.goanpeca.agentconsumption", category: "store")
    private var timer: Timer?

    /// The defaults read the real login files, the real defaults and Application Support; tests pass
    /// their own fetchers, defaults, directory and holiday session.
    init(
        notifier: any AlertDelivering, defaults: UserDefaults = .standard, supportDirectory: URL? = nil,
        holidaySession: URLSession = .shared, fetchers: [Provider: UsageFetch]? = nil
    ) {
        let session = URLSession(configuration: .ephemeral)
        let claude = ClaudeClient(session: session)
        let codex = CodexClient(session: session)
        self.fetchers =
            fetchers ?? [.claude: { try await claude.fetch(now: $0) }, .codex: { try await codex.fetch(now: $0) }]
        let support =
            supportDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentConsumption")
        holidays = HolidayStore(directory: support, session: holidaySession)
        self.notifier = notifier
        self.defaults = defaults
        refreshInterval = RefreshInterval(minutes: defaults.object(forKey: Self.intervalKey) as? Int)
        settings = WorkSettings.load(from: defaults)
        budget = BudgetSettings.load(from: defaults)
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
        defaults.set(interval.rawValue, forKey: Self.intervalKey)
        if timer != nil { scheduleTimer() }
    }

    /// - Parameter notify: false for `--dump`, which must not post or consume alerts.
    func refresh(notify: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let now = Date()

        await reloadCalendar(now: now)

        async let claudeResult = fetch(.claude, now: now)
        async let codexResult = fetch(.codex, now: now)
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

    private func fetch(_ provider: Provider, now: Date) async -> Result<ProviderUsage, Error> {
        guard let fetcher = fetchers[provider] else { return .failure(ProviderError.notSignedIn("No fetcher")) }
        do {
            return .success(try await fetcher(now))
        } catch {
            return .failure(error)
        }
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
        new.save(to: defaults)
        calendar = new.calendar(holidays: new.countryCode == nil ? [] : loadedHolidays)
        Task { await reloadCalendar() }
    }

    /// Confirms the first-run settings, whatever country was left selected.
    func completeSetup() {
        var new = settings
        new.isConfigured = true
        update(new)
    }

    func updateBudget(_ new: BudgetSettings) {
        guard new != budget, new.totalUSD >= 0, new.codexLimitUSD >= 0 else { return }
        budget = new
        new.save(to: defaults)
    }

    /// The budgets to show: one shared pool, or one per provider. Empty when none has a spend reading.
    var budgetPools: [BudgetStatus] {
        BudgetStatus.pools(usages: Provider.allCases.compactMap { states[$0]?.usage }, settings: budget)
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

    // MARK: Alert state persistence

    private static let alertStateKey = "alertState"

    private func loadAlertState() -> AlertState {
        guard let data = defaults.data(forKey: Self.alertStateKey),
            let state = try? JSONDecoder().decode(AlertState.self, from: data)
        else { return AlertState() }
        return state
    }

    private func saveAlertState(_ state: AlertState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.alertStateKey)
        }
    }
}
