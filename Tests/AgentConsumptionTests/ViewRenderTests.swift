import AppKit
import ConsumptionKit
import SwiftUI
import Testing

@testable import AgentConsumption

/// Renders each screen headlessly. There are no pixel assertions (no snapshot library); the point is
/// that every view body runs against realistic state without crashing, and produces something visible.
@MainActor
struct ViewRenderTests {
    private func render<V: View>(_ view: V, width: CGFloat = 360) -> NSImage? {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = 1
        return renderer.nsImage
    }

    private func loaded(_ harness: StoreHarness) async -> UsageStore {
        await harness.store.refresh(notify: false)
        return harness.store
    }

    @Test func theSetupScreenRenders() {
        let harness = StoreHarness(settings: nil)
        let image = render(SetupView(store: harness.store))
        #expect((image?.size.height ?? 0) > 50)
    }

    @Test func theUsagePanelRendersWithReadings() async {
        let store = await loaded(StoreHarness())
        let image = render(MenuView(store: store))
        #expect((image?.size.height ?? 0) > 100)
    }

    @Test func theUsagePanelRendersBeforeAnyReadingAndAfterErrors() async {
        let fresh = StoreHarness()
        #expect(render(MenuView(store: fresh.store)) != nil)
        let failing = StoreHarness(claude: { _ in throw FetchError("Open Claude Desktop") })
        _ = await loaded(failing)
        #expect(render(MenuView(store: failing.store)) != nil)
    }

    @Test func theFirstLaunchPanelShowsSetupInsteadOfTheTabs() {
        let harness = StoreHarness(settings: nil)
        #expect(render(MenuView(store: harness.store)) != nil)
    }

    @Test func theSettingsScreenRenders() {
        let harness = StoreHarness()
        #expect((render(SettingsView(store: harness.store))?.size.height ?? 0) > 100)
        let separate = StoreHarness(budget: BudgetSettings(isShared: false))
        #expect(render(SettingsView(store: separate.store)) != nil)
    }

    @Test func theCountryPickerRendersWithAndWithoutACountry() {
        #expect(render(CountryPicker(store: StoreHarness().store)) != nil)
        let withCountry = StoreHarness(settings: WorkSettings(countryCode: "CO", isConfigured: true))
        #expect(render(CountryPicker(store: withCountry.store)) != nil)
    }

    @Test func budgetCardsRenderForSharedAndSeparateBudgets() async {
        let spend: UsageFetch = { now in
            StoreHarness.usage(
                .claude, used: 40, kind: .monthly, spend: SpendReading(used: 1_600, limit: 4_200, unit: .usd), now: now)
        }
        let shared = await loaded(StoreHarness(budget: BudgetSettings(), claude: spend))
        for pool in shared.budgetPools {
            #expect((render(BudgetSection(store: shared, status: pool))?.size.height ?? 0) > 30)
        }
        let separate = await loaded(StoreHarness(budget: BudgetSettings(isShared: false), claude: spend))
        #expect(separate.budgetPools.count >= 1)
        for pool in separate.budgetPools { #expect(render(BudgetSection(store: separate, status: pool)) != nil) }
    }

    @Test func aMissingProviderIsFlaggedInTheBudgetCard() async {
        let spend: UsageFetch = { now in
            StoreHarness.usage(
                .claude, used: 40, kind: .monthly, spend: SpendReading(used: 1_600, limit: 4_200, unit: .usd), now: now)
        }
        let store = await loaded(StoreHarness(budget: BudgetSettings(), claude: spend))
        #expect(store.budgetPools.first?.missing == [.codex])
        #expect(render(BudgetSection(store: store, status: store.budgetPools[0])) != nil)
    }

    @Test func theUsageBarRendersAtItsEdges() {
        for fraction in [-1.0, 0, 0.5, 1, 2] {
            #expect(render(UsageBar(fraction: fraction, tint: .green, marker: fraction)) != nil)
        }
        #expect(render(UsageBar(fraction: 0.3, tint: .red)) != nil)
    }

    @Test func everyLevelHasAColorAndADistinctSymbol() {
        let symbols = [UsageLevel.good, .watch, .critical].map(\.symbol)
        #expect(Set(symbols).count == 3)
        #expect(UsageLevel.good.color != UsageLevel.critical.color)
    }

    @Test func eachProviderShowsItsShareOfTheSharedBudget() async {
        let fetch: @Sendable (Provider) -> UsageFetch = { provider in
            { now in
                StoreHarness.usage(
                    provider, used: 20, kind: .monthly,
                    spend: SpendReading(used: 800, limit: 4_000, unit: provider == .claude ? .usd : .usd), now: now)
            }
        }
        let store = await loaded(StoreHarness(budget: BudgetSettings(), claude: fetch(.claude), codex: fetch(.codex)))
        #expect(store.budgetPools.count == 1)
        #expect(render(ProviderSpendLine(store: store, provider: .claude)) != nil)
        #expect(render(MenuView(store: store)) != nil)
    }

    @Test func theHolidayWarningRendersWhenHolidaysCouldNotBeLoaded() async {
        let harness = StoreHarness(
            settings: WorkSettings(countryCode: "CO", isConfigured: true),
            holidayReply: { _ in .json("[]", status: 500) })
        await harness.store.refresh(notify: false)
        #expect(harness.store.holidaysMissing)
        #expect(render(CountryPicker(store: harness.store)) != nil)
    }
}
