import Foundation
import Testing

@testable import ConsumptionKit

struct UsageModelsTests {
    @Test func windowKindsHaveTheirNaturalLengths() {
        #expect(WindowKind.session.defaultLength == 5 * 3600)
        #expect(WindowKind.weekly.defaultLength == 7 * 86_400)
        #expect(WindowKind.monthly.defaultLength == 30 * 86_400)
        #expect(UsageWindow(kind: .monthly, usedPercent: 0, resetsAt: nil).length == 30 * 86_400)
    }

    @Test func headlinePrefersWeeklyThenMonthly() {
        let weekly = UsageWindow(kind: .weekly, usedPercent: 1, resetsAt: nil)
        let monthly = UsageWindow(kind: .monthly, usedPercent: 2, resetsAt: nil)
        func usage(_ windows: [UsageWindow]) -> ProviderUsage {
            ProviderUsage(provider: .claude, plan: nil, windows: windows, fetchedAt: .now)
        }
        #expect(usage([monthly, weekly]).headline == weekly)
        #expect(usage([monthly]).headline == monthly)
        #expect(usage([]).headline == nil)
    }
}
