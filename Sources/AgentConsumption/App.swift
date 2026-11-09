import SwiftUI

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
        guard let lock = SingleInstanceLock.acquire(at: file) else { exit(0) }
        instanceLock = lock
        HarnessConsumptionApp.main()
    }

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
    /// The app keeps its menu bar item: when macOS takes it out, it goes straight back in instead of the
    /// app quitting, which is what an unbound `MenuBarExtra` does.
    @State private var isInserted = true
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
            if !inserted { isInserted = true }
        }
    }
}
