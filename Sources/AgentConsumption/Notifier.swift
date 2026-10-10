import ConsumptionKit
import Foundation
import UserNotifications
import os

/// Delivers planner alerts as macOS notifications. Needs a bundled app (`make app`); under
/// `swift run` there is no bundle, so alerts are only logged.
@MainActor
final class Notifier {
    private let log = Logger(subsystem: "com.goanpeca.agentconsumption", category: "notify")
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { [log] granted, error in
            log.notice(
                "notification permission granted=\(granted) error=\(String(describing: error), privacy: .public)")
        }
    }

    func post(_ alert: UsageAlert) {
        log.notice("alert \(alert.id, privacy: .public): \(alert.title, privacy: .public)")
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = alert.kind == .nearlyOut ? .default : nil
        center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: nil))
    }
}
