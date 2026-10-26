import AppKit
import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

@MainActor
struct StoreLifecycleTests {
    @Test func startingFetchesRightAway() async {
        let first = AsyncStream<Void>.makeStream()
        let harness = StoreHarness(claude: { now in
            first.continuation.yield()
            return StoreHarness.usage(.claude, used: 10, now: now)
        })
        harness.store.start()
        var iterator = first.stream.makeAsyncIterator()
        await iterator.next()
        #expect(harness.claudeCalls.value >= 1)
    }

    @Test func theDefaultClaudeConfigLivesInDesktopsApplicationSupport() {
        let home = URL(fileURLWithPath: "/fake/home")
        #expect(
            DesktopAuth.configFile(home: home).path == "/fake/home/Library/Application Support/Claude/config.json")
    }

    @Test func aMissingAccentSelectorFallsBackToTheGivenColor() {
        let fallback = NSColor.systemPurple
        #expect(NSColor.accent("thisSelectorDoesNotExist", fallback: fallback) == fallback)
        for name in ["controlAccentGreenColor", "controlAccentOrangeColor", "controlAccentRedColor"] {
            #expect(NSColor.accent(name, fallback: fallback) != fallback)
        }
    }
}
