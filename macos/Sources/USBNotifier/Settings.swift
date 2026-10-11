import Foundation

/// UserDefaults keys and default values behind the @AppStorage settings in MenuView.
/// Non-view code reads the same values through the static accessors below.
/// (Named AppSettings so it does not shadow SwiftUI's `Settings` scene.)
enum AppSettings {
    enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let soundsEnabled = "soundsEnabled"
        static let connectSound = "connectSound"
        static let disconnectSound = "disconnectSound"
        static let replacePrevious = "replacePrevious"
    }

    enum Default {
        static let notificationsEnabled = true
        static let soundsEnabled = true
        static let connectSound = "Frog"
        static let disconnectSound = "Frog"
        static let replacePrevious = false
    }

    static var notificationsEnabled: Bool { value(Key.notificationsEnabled, Default.notificationsEnabled) }
    static var soundsEnabled: Bool { value(Key.soundsEnabled, Default.soundsEnabled) }
    static var connectSound: String { value(Key.connectSound, Default.connectSound) }
    static var disconnectSound: String { value(Key.disconnectSound, Default.disconnectSound) }
    static var replacePrevious: Bool { value(Key.replacePrevious, Default.replacePrevious) }

    // Same semantics as @AppStorage: the default applies while the key is unset.
    private static func value<T>(_ key: String, _ defaultValue: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
    }
}
