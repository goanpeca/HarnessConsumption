import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

/// The app moved from `com.goanpeca.agentconsumption` to `com.goanpeca.harnessconsumption`. On first launch
/// it carries the user's settings over, but never the menu bar state macOS kept for the old identifier.
struct SettingsMigrationTests {
    @Test func copiesTheUsersSettingsIntoAnEmptyNewDomain() {
        let old = Sandbox()
        let new = Sandbox()
        WorkSettings(countryCode: "CO", isConfigured: true).save(to: old.defaults)
        BudgetSettings(totalUSD: 4200).save(to: old.defaults)
        old.defaults.set(15, forKey: "refreshMinutes")
        old.defaults.set(Data("{}".utf8), forKey: "alertState")
        #expect(SettingsMigration.run(from: old.defaults, to: new.defaults))
        #expect(WorkSettings.load(from: new.defaults).countryCode == "CO")
        #expect(WorkSettings.load(from: new.defaults).isConfigured)
        #expect(BudgetSettings.load(from: new.defaults).totalUSD == 4200)
        #expect(new.defaults.integer(forKey: "refreshMinutes") == 15)
        #expect(new.defaults.data(forKey: "alertState") != nil)
    }

    @Test func neverCopiesTheMenuBarStateMacOSKept() {
        let old = Sandbox()
        let new = Sandbox()
        WorkSettings(countryCode: "CO", isConfigured: true).save(to: old.defaults)
        old.defaults.set(false, forKey: "NSStatusItem VisibleCC Item-0")
        old.defaults.set(120, forKey: "NSStatusItem Preferred Position Item-0")
        SettingsMigration.run(from: old.defaults, to: new.defaults)
        #expect(new.defaults.object(forKey: "NSStatusItem VisibleCC Item-0") == nil)
        #expect(new.defaults.object(forKey: "NSStatusItem Preferred Position Item-0") == nil)
    }

    @Test func doesNothingOnceTheNewDomainHasSettings() {
        let old = Sandbox()
        let new = Sandbox()
        WorkSettings(countryCode: "CO", isConfigured: true).save(to: old.defaults)
        WorkSettings(countryCode: "DE", isConfigured: true).save(to: new.defaults)
        #expect(!SettingsMigration.run(from: old.defaults, to: new.defaults))
        #expect(WorkSettings.load(from: new.defaults).countryCode == "DE")
    }

    @Test func doesNothingWhenThereIsNothingToCarryOver() {
        let new = Sandbox()
        #expect(!SettingsMigration.run(from: Sandbox().defaults, to: new.defaults))
        #expect(!WorkSettings.load(from: new.defaults).isConfigured)
    }

    @Test func copiesOnlyTheKeysThatExist() {
        let old = Sandbox()
        let new = Sandbox()
        BudgetSettings(totalUSD: 99).save(to: old.defaults)
        #expect(SettingsMigration.run(from: old.defaults, to: new.defaults))
        #expect(BudgetSettings.load(from: new.defaults).totalUSD == 99)
        #expect(new.defaults.object(forKey: "refreshMinutes") == nil)
    }

    @Test func theOldIdentifierIsTheOneThisAppShippedWith() {
        #expect(SettingsMigration.oldDomain == "com.goanpeca.agentconsumption")
    }
}
