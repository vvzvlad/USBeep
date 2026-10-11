import SwiftUI

/// Colours of the menu window; the window is always dark.
private enum Theme {
    static let accent = Color(rgb: 0xFF5C8F)
    static let background = Color(rgb: 0x13151B)
    static let speed = Color(rgb: 0x4DA3FF)
    static let power = Color(rgb: 0xFF9F2E)
}

private extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

/// Content of the menu-bar window: header with the settings menu behind the
/// gear, and the device list.
struct MenuView: View {
    @ObservedObject var monitor: USBMonitor

    @AppStorage(AppSettings.Key.notificationsEnabled)
    private var notificationsEnabled = AppSettings.Default.notificationsEnabled
    @AppStorage(AppSettings.Key.soundsEnabled)
    private var soundsEnabled = AppSettings.Default.soundsEnabled
    @AppStorage(AppSettings.Key.connectSound)
    private var connectSound = AppSettings.Default.connectSound
    @AppStorage(AppSettings.Key.disconnectSound)
    private var disconnectSound = AppSettings.Default.disconnectSound
    @AppStorage(AppSettings.Key.replacePrevious)
    private var replacePrevious = AppSettings.Default.replacePrevious

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider()

            deviceSection
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .frame(width: 380)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            monitor.refresh()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.accent.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("USBeep")
                    .font(.system(size: 16, weight: .semibold))
                Text(summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let total = USBDevice.formatPower(milliamps: totalMilliamps) {
                Badge(text: total, color: Theme.accent, fontSize: 13)
                    .help("Total current allocated on the 5 V bus: \(totalMilliamps) mA")
            }
            settingsMenu
        }
    }

    /// "3 devices · 1 hub"; hubs are not counted as devices.
    private var summary: String {
        let hubs = monitor.devices.filter(\.isHub).count
        let others = monitor.devices.count - hubs
        var text = "\(others) \(others == 1 ? "device" : "devices")"
        if hubs > 0 {
            text += " · \(hubs) \(hubs == 1 ? "hub" : "hubs")"
        }
        return text
    }

    private var totalMilliamps: Int {
        monitor.devices.compactMap(\.powerMilliamps).reduce(0, +)
    }

    // MARK: - Devices

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("USB DEVICES")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            if monitor.devices.isEmpty {
                Text("No USB devices")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(monitor.devices) { device in
                            DeviceRow(device: device)
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sounds

    /// Submenu of system sounds; picking one plays it as a preview.
    private func soundPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: Binding(
            get: { selection.wrappedValue },
            set: { newValue in
                selection.wrappedValue = newValue
                SoundPlayer.play(newValue)
            }
        )) {
            ForEach(SoundPlayer.systemSounds, id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Settings

    private var settingsMenu: some View {
        Menu {
                Toggle("Notifications", isOn: $notificationsEnabled)
                Toggle("Sounds", isOn: $soundsEnabled)
                Group {
                    soundPicker("Connect sound", selection: $connectSound)
                    soundPicker("Disconnect sound", selection: $disconnectSound)
                }
                .disabled(!soundsEnabled)
                Divider()
                Toggle("Replace previous notification", isOn: $replacePrevious)
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LaunchAtLogin.setEnabled(newValue)
                        // Show the real state: registration can fail or need approval.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                ))
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
    }
}

private struct DeviceRow: View {
    let device: USBDevice

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: device.symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.product)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let speed = device.speedText {
                        Badge(text: speed, color: Theme.speed)
                    }
                    if let power = device.powerText {
                        Badge(text: power, color: Theme.power)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(identity)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForEach(device.serialPorts, id: \.self) { path in
                    SerialPortButton(path: path)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .help(tooltip)
    }

    /// "Vendor · Category" with only the parts that exist; nil if neither does.
    private var detail: String? {
        let parts = [device.vendor, device.category?.name].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "303a:1001 · SN FC:01:2C:D1:E5:EC"; just the VID:PID without a serial number.
    private var identity: String {
        guard let serial = device.serialNumber else { return device.vidPid }
        return "\(device.vidPid) · SN \(serial)"
    }

    private var tooltip: String {
        guard let milliamps = device.powerMilliamps else { return device.vidPid }
        return "\(device.vidPid) · \(milliamps) mA @ 5 V"
    }
}

/// Callout path of a serial port; a click copies it to the clipboard and the
/// icon briefly turns into a checkmark.
private struct SerialPortButton: View {
    let path: String

    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 4) {
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Theme.accent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy path")
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)

        copied = true
        // A repeated click restarts the 1.5 s instead of being cut short by the earlier one.
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}

/// Capsule with coloured text, a 15% fill and a 40% stroke of the same colour.
private struct Badge: View {
    let text: String
    let color: Color
    var fontSize: CGFloat = 11

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            // Circular style: with the default continuous style the fill pokes
            // out past the stroke at the capsule ends.
            .background(Capsule(style: .circular).fill(color.opacity(0.15)))
            .overlay(Capsule(style: .circular).strokeBorder(color.opacity(0.4), lineWidth: 1))
            .fixedSize()
    }
}
