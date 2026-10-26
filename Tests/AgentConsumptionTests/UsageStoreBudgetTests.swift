import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

@MainActor
struct UsageStoreBudgetTests {

    @Test func aSharedBudgetShowsOneCombinedPercent() async {
        let (claude, codex) = StoreHarness.spending(claude: 1_000, codexCredits: 10_000)  // $1000 + $1000 of $4000
        let harness = StoreHarness(budget: BudgetSettings(), claude: claude, codex: codex)
        await harness.store.refresh(notify: false)
        #expect(harness.store.budgetPools.count == 1)
        #expect(harness.store.menuBarTitle == "◔ 50%")
    }

    @Test func aSharedBudgetIsMarkedIncompleteWhenAProviderFails() async {
        let (claude, _) = StoreHarness.spending(claude: 1_000, codexCredits: 0)
        let harness = StoreHarness(budget: BudgetSettings(), claude: claude, codex: { _ in throw FetchError("down") })
        await harness.store.refresh(notify: false)
        #expect(harness.store.menuBarTitle == "◔ 75%?")
    }

    @Test func separateBudgetsShowEachProvidersOwnPercent() async {
        let (claude, codex) = StoreHarness.spending(claude: 1_000, codexCredits: 20_000)  // $1000 / 4000, $2000 / 4000
        let harness = StoreHarness(
            budget: BudgetSettings(claudeUSD: 4000, codexLimitUSD: 4000, isShared: false), claude: claude, codex: codex)
        await harness.store.refresh(notify: false)
        #expect(harness.store.budgetPools.count == 2)
        #expect(harness.store.menuBarTitle == "✳︎ 75%  ◎ 50%")
    }

    @Test func withoutSpendReadingsTheBudgetStaysOutOfTheWay() async {
        let harness = StoreHarness(budget: BudgetSettings())
        await harness.store.refresh(notify: false)
        #expect(harness.store.budgetPools.isEmpty)
        #expect(harness.store.menuBarTitle == "✳︎ 62%  ◎ 96%")
    }

    @Test func budgetChangesPersistAndInvalidOnesAreIgnored() {
        let sandbox = Sandbox()
        let harness = StoreHarness(sandbox: sandbox)
        harness.store.updateBudget(BudgetSettings(totalUSD: 1234, claudeUSD: 10, codexLimitUSD: 20, isShared: false))
        #expect(harness.store.budget.totalUSD == 1234)
        harness.store.updateBudget(BudgetSettings(totalUSD: -1))
        harness.store.updateBudget(BudgetSettings(codexLimitUSD: -5))
        #expect(harness.store.budget.totalUSD == 1234)
        let reloaded = StoreHarness(sandbox: sandbox)
        #expect(
            reloaded.store.budget == BudgetSettings(totalUSD: 1234, claudeUSD: 10, codexLimitUSD: 20, isShared: false))
    }
}
