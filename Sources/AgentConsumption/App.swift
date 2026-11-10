import SwiftUI
import os

/// Decides how the process runs before any menu bar item exists. A second copy of the app creating its
/// own item makes macOS mark the item as removed and quit both copies, and remember that at every later
/// launch; so `--dump` never starts the menu bar app, and a second launch leaves the running copy alone.
@main
enum Launcher {
    @MainActor static func main() {
        SettingsMigration.run(
            fromFirstOf: SettingsMigration.oldDomains.map { UserDefaults(suiteName: $0) }, to: .standard)
        if CommandLine.arguments.contains("--dump") { dump() }
        let identifier = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let file = SingleInstanceLock.defaultFile(
            identifier: identifier, temporary: FileManager.default.temporaryDirectory)
        switch SingleInstanceLock.acquire(at: file) {
        case let .acquired(lock):
            instanceLock = lock
        case .heldElsewhere:
            exit(0)
        case let .failed(reason):
            // Not proof of another copy: start anyway, without the guarantee, and say why.
            log.error("single-instance lock unavailable, starting without it: \(reason, privacy: .public)")
        }
        HarnessConsumptionApp.main()
    }

    private static let log = Logger(subsystem: "com.goanpeca.agentconsumption", category: "launch")

    /// Held until the process ends, so no second copy can start.
    @MainActor private static var instanceLock: SingleInstanceLock?

    /// Prints the current readings and exits, without a menu bar item.
    @MainActor private static func dump() -> Never {
        let store = UsageStore(notifier: Notifier())
        Task { @MainActor in
            await store.loadCountries()
            await store.refresh(notify: false)
            print(store.report)
            exit(0)
        }
        RunLoop.main.run()
        exit(0)
    }
}

struct HarnessConsumptionApp: App {
    @State private var store: UsageStore
    /// When macOS takes the menu bar item out, the app puts it back once instead of quitting (what an
    /// unbound `MenuBarExtra` does). Only once per launch: if macOS keeps hiding it, fighting is pointless.
    @State private var isInserted = true
    @State private var hasReinserted = false
    private let notifier: Notifier

    init() {
        let notifier = Notifier()
        let store = UsageStore(notifier: notifier)
        notifier.requestAuthorization()
        store.start()
        self.notifier = notifier
        _store = State(initialValue: store)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            MenuView(store: store)
        } label: {
            Text(store.menuBarTitle).monospacedDigit()
        }
        .menuBarExtraStyle(.window)
        .onChange(of: isInserted) { _, inserted in
            guard !inserted, !hasReinserted else { return }
            hasReinserted = true
            isInserted = true
        }
    }
}
