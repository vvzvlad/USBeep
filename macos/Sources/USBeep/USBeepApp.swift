import SwiftUI

@main
struct USBeepApp: App {
    @StateObject private var monitor: USBMonitor

    init() {
        // Started here rather than from the window, so events are tracked
        // from launch and not only after the menu-bar item is first opened.
        let notifier = Notifier()
        notifier.start()
        let monitor = USBMonitor(notifier: notifier)
        monitor.start()
        _monitor = StateObject(wrappedValue: monitor)
    }

    var body: some Scene {
        MenuBarExtra("USBeep", systemImage: "cable.connector") {
            MenuView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
