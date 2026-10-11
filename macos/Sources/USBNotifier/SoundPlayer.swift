import AppKit

/// Plays macOS system sounds for connect/disconnect events.
enum SoundPlayer {
    /// Sounds shipped in /System/Library/Sounds, played by name without extension.
    static let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    /// Plays the configured sound for the event, if sounds are enabled.
    static func play(for event: USBEvent) {
        guard AppSettings.soundsEnabled else { return }
        switch event {
        case .connected: play(AppSettings.connectSound)
        case .disconnected: play(AppSettings.disconnectSound)
        }
    }

    /// Plays a sound by name regardless of the toggle (used for previews).
    static func play(_ name: String) {
        guard let sound = NSSound(named: name) else { return }
        // NSSound(named:) returns a shared instance; restart it if it is still playing.
        sound.stop()
        sound.play()
    }
}
