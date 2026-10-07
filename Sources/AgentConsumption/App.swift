import SwiftUI

@main
struct AgentConsumptionApp: App {
    @State private var store: UsageStore
    private let notifier: Notifier

    init() {
        let notifier = Notifier()
        let store = UsageStore(notifier: notifier)
        if CommandLine.arguments.contains("--dump") {
            Task { @MainActor in
                await store.refresh(notify: false)
                print(store.report)
                exit(0)
            }
        } else {
            notifier.requestAuthorization()
            store.start()
        }
        self.notifier = notifier
        _store = State(initialValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: store)
        } label: {
            Text(store.menuBarTitle).monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
