import Foundation
import UserNotifications

/// Posts connect/disconnect notifications through UNUserNotificationCenter.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    /// Becomes the notification center delegate and asks for permission.
    /// A denial is fine: the app keeps working, `add` then fails silently.
    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func post(_ event: USBEvent, devices: [USBDevice]) {
        guard AppSettings.notificationsEnabled, !devices.isEmpty else { return }

        let content = UNMutableNotificationContent()
        // No content.sound: sounds are played separately by SoundPlayer.
        if devices.count == 1 {
            let device = devices[0]
            switch event {
            case .connected:
                content.title = "Connected"
                let details = [device.speedText, device.powerText].compactMap { $0 }
                content.body = details.isEmpty
                    ? device.name
                    : device.name + "\n" + details.joined(separator: " · ")
            case .disconnected:
                content.title = "Disconnected"
                content.body = device.name
            }
        } else {
            let verb = event == .connected ? "connected" : "disconnected"
            content.title = "\(devices.count) devices \(verb)"
            content.body = devices.map(\.name).joined(separator: "\n")
        }

        let center = UNUserNotificationCenter.current()
        if AppSettings.replacePrevious {
            center.removeAllDeliveredNotifications()
        }
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // The menu window becomes key without activating the app (see SPEC §4), so
    // banners are normally shown anyway; this keeps them visible if the app ever
    // does become active, when they would otherwise be suppressed.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
