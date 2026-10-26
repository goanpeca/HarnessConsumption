import ConsumptionKit
import SwiftUI

func dollars(_ value: Double) -> String {
    value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

/// One budget (shared, or a provider's own): what is left of it, and what to spend per work day.
struct BudgetSection: View {
    let store: UsageStore
    let status: BudgetStatus

    var body: some View {
        let pace = status.pace(calendar: store.calendar, now: .now)
        let level = status.window.level(pace: pace)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(status.title).font(.headline)
                Spacer()
                Text("\(Int(status.window.remainingPercent.rounded()))%")
                    .font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                Text("left").font(.subheadline).foregroundStyle(.secondary)
            }
            UsageBar(
                fraction: status.window.usedPercent / 100, tint: level.color,
                marker: pace.map { $0.targetUsedByEndOfToday / 100 }
            )
            .accessibilityHidden(true)
            HStack {
                Label {
                    Text(status.window.status(pace: pace)).foregroundStyle(.primary)
                } icon: {
                    Image(systemName: level.symbol).foregroundStyle(level.color)
                }
                Text("· \(dollars(status.remainingUSD)) of \(dollars(status.totalUSD)) left")
                Spacer()
                if let pace {
                    Text("\(dollars(status.dollarsPerDay(pace: pace)))/day · \(days(pace.workDaysLeft)) left")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            if !status.missing.isEmpty {
                Label(
                    "No spend reading from \(status.missing.map(\.displayName).joined(separator: ", ")); the total may be low.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.title)
        .accessibilityValue(spoken(status, pace: pace))
    }

    private func spoken(_ status: BudgetStatus, pace: WindowPace?) -> String {
        var parts = [
            "\(Int(status.window.remainingPercent.rounded())) percent left",
            "\(dollars(status.remainingUSD)) of \(dollars(status.totalUSD)) left",
            status.window.status(pace: pace),
        ]
        if let pace {
            parts.append("\(dollars(status.dollarsPerDay(pace: pace))) per work day, \(days(pace.workDaysLeft)) left")
        }
        return parts.joined(separator: ". ")
    }
}

/// What one provider has spent and how much of the shared budget that is.
struct ProviderSpendLine: View {
    let store: UsageStore
    let provider: Provider

    var body: some View {
        if let status = store.budgetPools.first(where: { $0.providers.count > 1 }),
            let spent = status.spentByProvider[provider]
        {
            Text("\(dollars(spent)) spent · \(Int((spent / status.totalUSD * 100).rounded()))% of the shared budget")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
