import Foundation

/// A USB device as shown in the list and in notifications, parsed from the
/// IORegistry properties of an `IOUSBHostDevice` service.
struct USBDevice: Identifiable, Equatable {
    /// IORegistry entry ID: unique per device instance, so two identical
    /// devices (same VID:PID) stay separate.
    let id: UInt64
    /// Display name: vendor + product, or just the product when it already
    /// starts with the vendor name.
    let name: String
    /// Product string alone; the list row shows the vendor on its second line.
    let product: String
    let vendor: String?
    let vendorID: Int
    let productID: Int
    /// "USB 2.0 · 480 Mb/s"
    let speedText: String?
    /// Current allocated on the 5 V bus; nil when absent or 0.
    let powerMilliamps: Int?
    /// "2.5 W"
    let powerText: String?
    let category: USBCategory?

    /// - Parameter interfaces: properties of the device's IOUSBHostInterface children.
    init(registryID: UInt64, properties: [String: Any], interfaces: [[String: Any]] = []) {
        let product = Self.string(properties, "kUSBProductString")
            ?? Self.string(properties, "USB Product Name")
            ?? "Unknown device"
        let vendor = Self.string(properties, "kUSBVendorString")
            ?? Self.string(properties, "USB Vendor Name")

        id = registryID
        self.product = product
        self.vendor = vendor
        name = Self.displayName(vendor: vendor, product: product)
        vendorID = properties["idVendor"] as? Int ?? 0
        productID = properties["idProduct"] as? Int ?? 0
        speedText = Self.speedText(linkSpeed: properties["UsbLinkSpeed"] as? Int,
                                   usbSpeed: properties["USBSpeed"] as? Int,
                                   bcdUSB: properties["bcdUSB"] as? Int)
        let milliamps = properties["UsbPowerSinkAllocation"] as? Int ?? 0
        powerMilliamps = milliamps > 0 ? milliamps : nil
        powerText = Self.formatPower(milliamps: milliamps)
        let detected = USBCategory.detect(deviceClass: properties["bDeviceClass"] as? Int, interfaces: interfaces)
        // iPhones and iPads expose a PTP (still image) interface first; "Camera" would mislead.
        category = detected == .stillCamera && vendorID == USBCategory.appleVendorID ? .phone : detected
    }

    /// "05ac:12a8"
    var vidPid: String {
        String(format: "%04x:%04x", vendorID, productID)
    }

    /// SF Symbol for the list row.
    var symbol: String {
        category?.symbol ?? USBCategory.fallbackSymbol
    }

    var isHub: Bool {
        category == .hub
    }

    // MARK: - Formatting

    /// Formats a link speed in bits/s with its USB generation:
    /// "USB 1.1 · 1.5 Mb/s", "USB 2.0 · 480 Mb/s", "USB 3.2 · 5 Gb/s". Nil for 0.
    /// The generation comes from `bcdUSB` when known, otherwise from the speed.
    static func formatLinkSpeed(bitsPerSecond: Int, bcdUSB: Int? = nil) -> String? {
        guard bitsPerSecond > 0 else { return nil }
        let rate = bitsPerSecond < 1_000_000_000
            ? "\(formatNumber(Double(bitsPerSecond) / 1_000_000)) Mb/s"
            : "\(formatNumber(Double(bitsPerSecond) / 1_000_000_000)) Gb/s"
        let generation = bcdUSB.flatMap(usbVersion(bcd:)) ?? usbGeneration(bitsPerSecond: bitsPerSecond)
        return "\(generation) · \(rate)"
    }

    /// USB version the device declares in `bcdUSB` (BCD): 0x0110 → "USB 1.1",
    /// 0x0200/0x0210 → "USB 2.0", 0x0320 → "USB 3.2", 0x0400 → "USB4". Nil for 0.
    /// A keyboard on a 12 Mb/s link usually declares 2.0, which PlugTalk shows too.
    static func usbVersion(bcd: Int) -> String? {
        let major = (bcd >> 8) & 0xFF
        let minor = (bcd >> 4) & 0xF
        switch major {
        case 0: return nil
        case 2: return "USB 2.0"   // 2.1 only marks LPM/BOS support, not a new version
        case 4...: return "USB4"
        default: return "USB \(major).\(minor)"
        }
    }

    /// Generation label implied by the link speed.
    static func usbGeneration(bitsPerSecond: Int) -> String {
        switch bitsPerSecond {
        case ...12_000_000: return "USB 1.1"
        case ...480_000_000: return "USB 2.0"
        case ..<40_000_000_000: return "USB 3.2"
        default: return "USB4"
        }
    }

    /// Formats a `USBSpeed` value (`tIOUSBHostConnectionSpeed`). Note the enum order:
    /// 1 is Full (12 Mb/s) and 2 is Low (1.5 Mb/s) — unlike the legacy "Device Speed" key.
    static func formatUSBSpeed(_ speed: Int, bcdUSB: Int? = nil) -> String? {
        let bitsPerSecond: [Int: Int] = [
            1: 12_000_000,      // Full
            2: 1_500_000,       // Low
            3: 480_000_000,     // High
            4: 5_000_000_000,   // Super
            5: 10_000_000_000,  // SuperPlus
            6: 20_000_000_000   // SuperPlusBy2
        ]
        return bitsPerSecond[speed].flatMap { formatLinkSpeed(bitsPerSecond: $0, bcdUSB: bcdUSB) }
    }

    /// Prefers the actual link speed ("UsbLinkSpeed"), falls back to the "USBSpeed" enum.
    static func speedText(linkSpeed: Int?, usbSpeed: Int?, bcdUSB: Int? = nil) -> String? {
        if let linkSpeed, let text = formatLinkSpeed(bitsPerSecond: linkSpeed, bcdUSB: bcdUSB) {
            return text
        }
        return usbSpeed.flatMap { formatUSBSpeed($0, bcdUSB: bcdUSB) }
    }

    /// Converts current on the 5 V bus to watts: 500 mA → "2.5 W". Nil for 0.
    static func formatPower(milliamps: Int) -> String? {
        guard milliamps > 0 else { return nil }
        return "\(formatNumber(Double(milliamps) * 5 / 1000)) W"
    }

    /// Up to two decimals with trailing zeros dropped: 480 → "480", 2.5 → "2.5".
    static func formatNumber(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    // MARK: - Parsing helpers

    private static func string(_ properties: [String: Any], _ key: String) -> String? {
        guard let value = properties[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func displayName(vendor: String?, product: String) -> String {
        guard let vendor, !product.lowercased().hasPrefix(vendor.lowercased()) else {
            return product
        }
        return "\(vendor) \(product)"
    }
}

/// Kind of device derived from USB class codes, with its SF Symbol.
struct USBCategory: Equatable {
    let name: String
    let symbol: String

    static let storage = USBCategory(name: "Storage", symbol: "externaldrive")
    static let keyboard = USBCategory(name: "Keyboard", symbol: "keyboard")
    static let mouse = USBCategory(name: "Mouse", symbol: "computermouse")
    static let inputDevice = USBCategory(name: "Input device", symbol: "keyboard")
    static let audio = USBCategory(name: "Audio", symbol: "speaker.wave.2")
    static let videoCamera = USBCategory(name: "Camera", symbol: "video")
    static let stillCamera = USBCategory(name: "Camera", symbol: "camera")
    static let printer = USBCategory(name: "Printer", symbol: "printer")
    static let communication = USBCategory(name: "Communication", symbol: "antenna.radiowaves.left.and.right")
    static let wireless = USBCategory(name: "Wireless", symbol: "dot.radiowaves.left.and.right")
    static let smartCard = USBCategory(name: "Smart card", symbol: "creditcard")
    static let displayAdapter = USBCategory(name: "Display adapter", symbol: "display")
    static let hub = USBCategory(name: "Hub", symbol: "point.3.connected.trianglepath.dotted")
    static let phone = USBCategory(name: "Phone", symbol: "iphone")

    static let appleVendorID = 0x05AC

    /// Symbol for devices without a known category.
    static let fallbackSymbol = "cable.connector"

    /// Maps a USB class code (and, for HID, the protocol) to a category.
    static func from(classCode: Int, protocolCode: Int?) -> USBCategory? {
        switch classCode {
        case 0x01: return .audio
        case 0x02, 0x0A: return .communication
        case 0x03:
            switch protocolCode {
            case 1: return .keyboard
            case 2: return .mouse
            default: return .inputDevice
            }
        case 0x06: return .stillCamera
        case 0x07: return .printer
        case 0x08: return .storage
        case 0x09: return .hub
        case 0x0B: return .smartCard
        case 0x0E: return .videoCamera
        case 0x11: return .displayAdapter
        case 0xE0: return .wireless
        default: return nil
        }
    }

    /// Uses the device class unless it defers to the interfaces (0, or 0xEF
    /// "Miscellaneous" for composite devices); then the first interface, in
    /// bInterfaceNumber order, whose class maps to a category.
    static func detect(deviceClass: Int?, interfaces: [[String: Any]]) -> USBCategory? {
        if let deviceClass, deviceClass != 0, deviceClass != 0xEF {
            return from(classCode: deviceClass, protocolCode: nil)
        }
        let ordered = interfaces.sorted {
            ($0["bInterfaceNumber"] as? Int ?? Int.max) < ($1["bInterfaceNumber"] as? Int ?? Int.max)
        }
        for interface in ordered {
            guard let classCode = interface["bInterfaceClass"] as? Int else { continue }
            if let category = from(classCode: classCode, protocolCode: interface["bInterfaceProtocol"] as? Int) {
                return category
            }
        }
        return nil
    }
}
