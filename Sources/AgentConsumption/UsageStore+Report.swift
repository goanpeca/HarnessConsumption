import ConsumptionKit
import Foundation

/// Text renderings of the store: the `--dump` report and the menu bar title.
extension UsageStore {
    /// Plain-text report for `AgentConsumption --dump`.
    var report: String {
        var lines = ["menu bar: \(menuBarTitle)"]
        for provider in Provider.allCases {
            let state = states[provider]
            lines.append("\(provider.displayName) (\(state?.usage?.plan ?? "?"))")
            if let error = state?.error { lines.append("  error: \(error)") }
            for window in state?.usage?.windows ?? [] {
                var line = "  \(window.kind.displayName): \(Int(window.remainingPercent.rounded()))% left"
                if let reset = window.resetsAt { line += ", resets \(reset.formatted())" }
                if window.kind != .session, let pace = pace(provider, window.kind) {
                    line += String(
                        format: ", today %.1f%% over %d work days%@", pace.todayShare, pace.workDaysLeft,
                        pace.isOverPace ? " (OVER PACE)" : "")
                }
                lines.append(line)
            }
            let month = monthOutlook(provider)
            if let projected = month.projectedPercentLeft, let daily = month.dailyShare {
                lines.append(String(format: "  month: %.0f%% of a week left, %.1f%%/day", projected, daily))
            }
        }
        for status in budgetPools {
            var line = String(
                format: "%@: $%.0f of $%.0f spent, %.0f%% left", status.title, status.spentUSD, status.totalUSD,
                status.window.remainingPercent)
            if let pace = status.pace(calendar: calendar, now: .now) {
                line += String(
                    format: ", $%.0f/day over %d work days", status.dollarsPerDay(pace: pace), pace.workDaysLeft)
            }
            lines.append(line)
        }
        let month = monthOutlook(.claude)
        lines.append(
            "counted days: \(month.workDaysLeft) of \(month.workDaysInMonth) left this month "
                + "(\(settings.summary(countries: countries)))"
                + (holidaysMissing ? " (holidays unavailable)" : ""))
        return lines.joined(separator: "\n")
    }

    func symbol(for provider: Provider) -> String { provider == .claude ? "✳︎" : "◎" }

    /// The share of the shared budget left (`◔ 62%`), or without a budget `✳︎ 62%  ◎ 80%`: weekly (or
    /// monthly spend) quota left per provider. Plain text on purpose: the menu bar draws it in the
    /// system's own color.
    var menuBarTitle: String {
        guard settings.isConfigured else { return "Set up" }
        let pools = budgetPools
        if !pools.isEmpty {
            return pools.map { pool in
                let symbol = pool.providers.count > 1 ? "◔" : symbol(for: pool.providers[0])
                let partial = !pool.missing.isEmpty || pool.providers.contains { states[$0]?.error != nil }
                return "\(symbol) \(Int(pool.window.remainingPercent.rounded()))%\(partial ? "?" : "")"
            }.joined(separator: "  ")
        }
        let parts = Provider.allCases.map { provider -> String in
            let symbol = symbol(for: provider)
            guard let window = states[provider]?.usage?.headline else { return "\(symbol) –" }
            let stale = states[provider]?.error != nil ? "?" : ""
            return "\(symbol) \(Int(window.remainingPercent.rounded()))%\(stale)"
        }
        return parts.joined(separator: "  ")
    }
}
