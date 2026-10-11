import Foundation
import ServiceManagement

/// Registers the app as a login item via SMAppService (requires a real bundle).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login: failed to \(enabled ? "register" : "unregister"): \(error.localizedDescription)")
        }
    }
}
