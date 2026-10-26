import ConsumptionKit
import SwiftUI

/// Shown instead of the panes on first launch: the work days depend on the country, so it has to be
/// confirmed before any number is paced over them.
struct SetupView: View {
    let store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Agent Consumption").font(.title3.weight(.semibold))
            Text(
                "Your limits are spread over the work days that remain. Choose the country whose public holidays count as days off, or none to count weekdays only."
            )
            .font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            CountryPicker(store: store)
            Text("You can change this, and which weekdays count, later in Settings.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Continue") { store.completeSetup() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
