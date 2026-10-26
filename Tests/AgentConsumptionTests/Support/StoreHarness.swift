import ConsumptionKit
import Foundation

@testable import AgentConsumption

@MainActor
final class RecordingNotifier: AlertDelivering {
    private(set) var posted: [UsageAlert] = []
    func post(_ alert: UsageAlert) { posted.append(alert) }
    func count(_ kind: UsageAlert.Kind) -> Int { posted.filter { $0.kind == kind }.count }
}

struct FetchError: Error, LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// A `UsageStore` wired to nothing real: scripted fetchers, a recording notifier, a sandboxed defaults
/// suite and directory, and a stubbed holiday service.
@MainActor
struct StoreHarness {
    let sandbox: Sandbox
    let notifier = RecordingNotifier()
    let holidaySession: StubSession
    let store: UsageStore
    let claudeCalls = LockedBox(0)
    let codexCalls = LockedBox(0)

    /// Nager.Date answers: this one holiday for any year, or an error status.
    nonisolated static let holidayJSON = #"[{"date":"2026-10-12"},{"date":"2026-11-02"}]"#

    init(
        sandbox: Sandbox = Sandbox(),
        settings: WorkSettings? = WorkSettings(countryCode: nil),
        budget: BudgetSettings? = nil,
        holidayReply: @escaping @Sendable (URLRequest) -> StubSession.Reply = { _ in .json(Self.holidayJSON) },
        claude: UsageFetch? = nil,
        codex: UsageFetch? = nil
    ) {
        self.sandbox = sandbox
        if let settings { settings.save(to: sandbox.defaults) }
        if let budget { budget.save(to: sandbox.defaults) }
        holidaySession = StubSession(holidayReply)
        let claudeCalls = claudeCalls
        let codexCalls = codexCalls
        let defaultClaude: UsageFetch = { now in
            claudeCalls.value += 1
            return Self.usage(.claude, used: 38, now: now)
        }
        let defaultCodex: UsageFetch = { now in
            codexCalls.value += 1
            return Self.usage(.codex, used: 4, now: now)
        }
        store = UsageStore(
            notifier: notifier, defaults: sandbox.defaults, supportDirectory: sandbox.directory,
            holidaySession: holidaySession.session,
            fetchers: [
                .claude: claude.map { fetch in
                    { now in
                        claudeCalls.value += 1; return try await fetch(now)
                    }
                } ?? defaultClaude,
                .codex: codex.map { fetch in
                    { now in
                        codexCalls.value += 1; return try await fetch(now)
                    }
                } ?? defaultCodex,
            ])
    }

    /// A reading with one window, resetting `days` from `now`.
    nonisolated static func usage(
        _ provider: Provider, used: Double, kind: WindowKind = .weekly, days: Double = 3, spend: SpendReading? = nil,
        now: Date
    ) -> ProviderUsage {
        let window = UsageWindow(
            kind: kind, usedPercent: used, resetsAt: now.addingTimeInterval(days * 86_400),
            length: kind.defaultLength)
        return ProviderUsage(provider: provider, plan: "test", windows: [window], fetchedAt: now, spend: spend)
    }

    nonisolated static func spending(claude: Double, codexCredits: Double) -> (UsageFetch, UsageFetch) {
        (
            { now in
                Self.usage(
                    .claude, used: 10, kind: .monthly, spend: SpendReading(used: claude, limit: 4200, unit: .usd),
                    now: now)
            },
            { now in
                Self.usage(
                    .codex, used: 10, kind: .monthly,
                    spend: SpendReading(used: codexCredits, limit: 40_000, unit: .credits), now: now)
            }
        )
    }
}
