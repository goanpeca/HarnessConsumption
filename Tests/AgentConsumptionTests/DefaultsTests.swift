import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

struct DefaultsTests {
    // MARK: WorkSettings

    @Test func nothingSavedMeansAFirstRunWithTheSystemRegionSuggested() {
        let settings = WorkSettings.load(from: Sandbox().defaults)
        #expect(!settings.isConfigured)
        #expect(settings.countryCode == WorkSettings.suggestedRegion)
        #expect(settings.weekdays == WorkSettings.monToFri)
    }

    @Test func savedSettingsComeBackExactly() {
        let sandbox = Sandbox()
        let saved = WorkSettings(weekdays: [2, 4, 7], countryCode: "DE", skipHolidays: false, isConfigured: true)
        saved.save(to: sandbox.defaults)
        #expect(WorkSettings.load(from: sandbox.defaults) == saved)
    }

    @Test func savingTwiceKeepsTheLatest() {
        let sandbox = Sandbox()
        WorkSettings(countryCode: "DE").save(to: sandbox.defaults)
        WorkSettings(countryCode: "US").save(to: sandbox.defaults)
        #expect(WorkSettings.load(from: sandbox.defaults).countryCode == "US")
    }

    @Test func corruptSettingsFallBackToAFirstRun() {
        let sandbox = Sandbox()
        sandbox.defaults.set(Data("not json".utf8), forKey: "workSettings")
        #expect(!WorkSettings.load(from: sandbox.defaults).isConfigured)
    }

    @Test func savedSettingsWithNoWeekdaysAreNotTrusted() {
        let sandbox = Sandbox()
        WorkSettings(weekdays: [], countryCode: "DE", isConfigured: true).save(to: sandbox.defaults)
        let loaded = WorkSettings.load(from: sandbox.defaults)
        #expect(!loaded.weekdays.isEmpty)
        #expect(!loaded.isConfigured)
    }

    @Test func settingsFromBeforeSetupExistedLoadAsConfigured() {
        let sandbox = Sandbox()
        sandbox.defaults.set(
            Data(#"{"weekdays":[2,3,4,5,6],"countryCode":"CO","skipHolidays":true}"#.utf8), forKey: "workSettings")
        let loaded = WorkSettings.load(from: sandbox.defaults)
        #expect(loaded.isConfigured)
        #expect(loaded.countryCode == "CO")
    }

    // MARK: BudgetSettings

    @Test func nothingSavedMeansTheDefaultBudget() {
        #expect(BudgetSettings.load(from: Sandbox().defaults) == BudgetSettings())
    }

    @Test func aSavedBudgetComesBackExactly() {
        let sandbox = Sandbox()
        let saved = BudgetSettings(totalUSD: 1500, claudeUSD: 700, codexLimitUSD: 800, isShared: false)
        saved.save(to: sandbox.defaults)
        #expect(BudgetSettings.load(from: sandbox.defaults) == saved)
    }

    @Test func aCorruptBudgetFallsBackToTheDefault() {
        let sandbox = Sandbox()
        sandbox.defaults.set(Data("{".utf8), forKey: "budgetSettings")
        #expect(BudgetSettings.load(from: sandbox.defaults) == BudgetSettings())
    }

    @Test func settingsAndBudgetDoNotShareAKey() {
        let sandbox = Sandbox()
        WorkSettings(countryCode: "DE", isConfigured: true).save(to: sandbox.defaults)
        BudgetSettings(totalUSD: 1).save(to: sandbox.defaults)
        #expect(WorkSettings.load(from: sandbox.defaults).countryCode == "DE")
        #expect(BudgetSettings.load(from: sandbox.defaults).totalUSD == 1)
    }

    @Test func separateSandboxesDoNotLeakIntoEachOther() {
        let first = Sandbox()
        let second = Sandbox()
        BudgetSettings(totalUSD: 99).save(to: first.defaults)
        #expect(BudgetSettings.load(from: second.defaults) == BudgetSettings())
    }
}
