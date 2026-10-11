import XCTest
@testable import USBNotifier

final class USBDeviceTests: XCTestCase {
    // MARK: - Parsing

    /// Real ioreg dump of an Apple Silicon device (values as NSNumber, like IOKit returns them).
    func testParsesRealIoregDump() {
        let properties: [String: Any] = [
            "USBSpeed": NSNumber(value: 3),
            "UsbLinkSpeed": NSNumber(value: 480_000_000),
            "UsbPowerSinkAllocation": NSNumber(value: 500),
            "USB Product Name": "TETRA PEI interface",
            "kUSBCurrentConfiguration": NSNumber(value: 1),
            "bcdUSB": NSNumber(value: 512),
            "locationID": NSNumber(value: 34_734_080),
            "idVendor": NSNumber(value: 0x0CAD),
            "idProduct": NSNumber(value: 0x9012)
        ]

        let device = USBDevice(registryID: 4_294_970_000, properties: properties)

        XCTAssertEqual(device.id, 4_294_970_000)
        XCTAssertEqual(device.name, "TETRA PEI interface")
        XCTAssertNil(device.vendor)
        XCTAssertEqual(device.vendorID, 0x0CAD)
        XCTAssertEqual(device.productID, 0x9012)
        XCTAssertEqual(device.vidPid, "0cad:9012")
        XCTAssertEqual(device.speedText, "USB 2.0 · 480 Mb/s")
        XCTAssertEqual(device.powerMilliamps, 500)
        XCTAssertEqual(device.powerText, "2.5 W")
    }

    /// ESP32 USB JTAG/serial debug unit from `ioreg` on a Mac: composite (0xEF), Full Speed,
    /// no UsbLinkSpeed or UsbPowerSinkAllocation, a CDC ACM serial port.
    func testParsesESP32SerialDevice() {
        let properties: [String: Any] = [
            "idVendor": NSNumber(value: 12346),
            "idProduct": NSNumber(value: 4097),
            "bcdUSB": NSNumber(value: 512),
            "USBSpeed": NSNumber(value: 1),
            "bDeviceClass": NSNumber(value: 239),
            "kUSBProductString": "USB JTAG/serial debug unit",
            "kUSBVendorString": "Espressif",
            "kUSBSerialNumberString": "FC:01:2C:D1:E5:EC",
            "USB Serial Number": "FC:01:2C:D1:E5:EC"
        ]
        let interfaces = [
            interface(number: 0, classCode: 0x02),
            interface(number: 1, classCode: 0x0A),
            interface(number: 2, classCode: 0xFF)
        ]

        let device = USBDevice(registryID: 1, properties: properties, interfaces: interfaces,
                               serialPorts: ["/dev/cu.usbmodem101"])

        XCTAssertEqual(device.vidPid, "303a:1001")
        XCTAssertEqual(device.serialNumber, "FC:01:2C:D1:E5:EC")
        XCTAssertEqual(device.category, .communication)
        XCTAssertEqual(device.speedText, "USB 2.0 · 12 Mb/s")
        XCTAssertNil(device.powerText)
        XCTAssertEqual(device.serialPorts, ["/dev/cu.usbmodem101"])
    }

    func testModernSerialNumberKeyWinsOverLegacy() {
        let device = USBDevice(registryID: 1, properties: [
            "kUSBSerialNumberString": "A1B2C3",
            "USB Serial Number": "LEGACY"
        ])
        XCTAssertEqual(device.serialNumber, "A1B2C3")
    }

    func testBlankSerialNumberIsNil() {
        XCTAssertNil(USBDevice(registryID: 1, properties: ["kUSBSerialNumberString": ""]).serialNumber)
        XCTAssertNil(USBDevice(registryID: 2, properties: ["USB Serial Number": "   "]).serialNumber)
        XCTAssertNil(USBDevice(registryID: 3, properties: [:]).serialNumber)
    }

    func testSerialPortsAreSorted() {
        let device = USBDevice(registryID: 1, properties: [:],
                               serialPorts: ["/dev/cu.usbserial-B", "/dev/cu.usbserial-A"])
        XCTAssertEqual(device.serialPorts, ["/dev/cu.usbserial-A", "/dev/cu.usbserial-B"])
    }

    func testModernStringKeysWinOverLegacy() {
        let device = USBDevice(registryID: 1, properties: [
            "kUSBProductString": "Ultra Fit",
            "USB Product Name": "Legacy Product",
            "kUSBVendorString": "SanDisk",
            "USB Vendor Name": "Legacy Vendor"
        ])

        XCTAssertEqual(device.vendor, "SanDisk")
        XCTAssertEqual(device.name, "SanDisk Ultra Fit")
    }

    func testVendorIsNotRepeatedWhenProductStartsWithIt() {
        let device = USBDevice(registryID: 1, properties: [
            "USB Product Name": "SanDisk Ultra Fit",
            "USB Vendor Name": "SanDisk"
        ])

        XCTAssertEqual(device.vendor, "SanDisk")
        XCTAssertEqual(device.name, "SanDisk Ultra Fit")
    }

    func testMissingNamesFallBackToUnknownDevice() {
        let device = USBDevice(registryID: 1, properties: [:])

        XCTAssertEqual(device.name, "Unknown device")
        XCTAssertNil(device.vendor)
        XCTAssertEqual(device.vidPid, "0000:0000")
        XCTAssertNil(device.speedText)
        XCTAssertNil(device.powerMilliamps)
        XCTAssertNil(device.powerText)
    }

    // MARK: - Speed

    func testFormatLinkSpeed() {
        XCTAssertEqual(USBDevice.formatLinkSpeed(bitsPerSecond: 1_500_000), "USB 1.1 · 1.5 Mb/s")
        XCTAssertEqual(USBDevice.formatLinkSpeed(bitsPerSecond: 12_000_000), "USB 1.1 · 12 Mb/s")
        XCTAssertEqual(USBDevice.formatLinkSpeed(bitsPerSecond: 480_000_000), "USB 2.0 · 480 Mb/s")
        XCTAssertEqual(USBDevice.formatLinkSpeed(bitsPerSecond: 5_000_000_000), "USB 3.2 · 5 Gb/s")
        XCTAssertEqual(USBDevice.formatLinkSpeed(bitsPerSecond: 20_000_000_000), "USB 3.2 · 20 Gb/s")
        XCTAssertEqual(USBDevice.formatLinkSpeed(bitsPerSecond: 40_000_000_000), "USB4 · 40 Gb/s")
        XCTAssertNil(USBDevice.formatLinkSpeed(bitsPerSecond: 0))
    }

    func testFormatUSBSpeedEnum() {
        XCTAssertNil(USBDevice.formatUSBSpeed(0))
        // Full and Low are 1 and 2 in tIOUSBHostConnectionSpeed — not the "Device Speed" order.
        XCTAssertEqual(USBDevice.formatUSBSpeed(1), "USB 1.1 · 12 Mb/s")
        XCTAssertEqual(USBDevice.formatUSBSpeed(2), "USB 1.1 · 1.5 Mb/s")
        XCTAssertEqual(USBDevice.formatUSBSpeed(3), "USB 2.0 · 480 Mb/s")
        XCTAssertEqual(USBDevice.formatUSBSpeed(4), "USB 3.2 · 5 Gb/s")
        XCTAssertEqual(USBDevice.formatUSBSpeed(5), "USB 3.2 · 10 Gb/s")
        XCTAssertEqual(USBDevice.formatUSBSpeed(6), "USB 3.2 · 20 Gb/s")
    }

    func testSpeedFallsBackToUSBSpeedWhenLinkSpeedIsAbsentOrZero() {
        let fullSpeed = USBDevice(registryID: 1, properties: ["USBSpeed": NSNumber(value: 1)])
        XCTAssertEqual(fullSpeed.speedText, "USB 1.1 · 12 Mb/s")

        let lowSpeed = USBDevice(registryID: 2, properties: [
            "UsbLinkSpeed": NSNumber(value: 0),
            "USBSpeed": NSNumber(value: 2)
        ])
        XCTAssertEqual(lowSpeed.speedText, "USB 1.1 · 1.5 Mb/s")

        let noSpeed = USBDevice(registryID: 3, properties: ["USBSpeed": NSNumber(value: 0)])
        XCTAssertNil(noSpeed.speedText)
    }

    func testLinkSpeedWinsOverUSBSpeed() {
        let device = USBDevice(registryID: 1, properties: [
            "UsbLinkSpeed": NSNumber(value: 5_000_000_000),
            "USBSpeed": NSNumber(value: 3)
        ])
        XCTAssertEqual(device.speedText, "USB 3.2 · 5 Gb/s")
    }

    func testGenerationComesFromBcdUSB() {
        XCTAssertEqual(USBDevice.usbVersion(bcd: 0x0110), "USB 1.1")
        XCTAssertEqual(USBDevice.usbVersion(bcd: 0x0200), "USB 2.0")
        XCTAssertEqual(USBDevice.usbVersion(bcd: 0x0210), "USB 2.0")
        XCTAssertEqual(USBDevice.usbVersion(bcd: 0x0300), "USB 3.0")
        XCTAssertEqual(USBDevice.usbVersion(bcd: 0x0320), "USB 3.2")
        XCTAssertEqual(USBDevice.usbVersion(bcd: 0x0400), "USB4")
        XCTAssertNil(USBDevice.usbVersion(bcd: 0))

        // A USB 2.0 receiver on a Full Speed link, as in PlugTalk's dropdown.
        let receiver = USBDevice(registryID: 1, properties: [
            "UsbLinkSpeed": NSNumber(value: 12_000_000),
            "bcdUSB": NSNumber(value: 0x0200)
        ])
        XCTAssertEqual(receiver.speedText, "USB 2.0 · 12 Mb/s")

        // Without bcdUSB the generation is still derived from the speed.
        let fallback = USBDevice(registryID: 2, properties: ["USBSpeed": NSNumber(value: 1)])
        XCTAssertEqual(fallback.speedText, "USB 1.1 · 12 Mb/s")
    }

    // MARK: - Power

    func testFormatPower() {
        XCTAssertEqual(USBDevice.formatPower(milliamps: 500), "2.5 W")
        XCTAssertEqual(USBDevice.formatPower(milliamps: 900), "4.5 W")
        XCTAssertNil(USBDevice.formatPower(milliamps: 0))
    }

    func testPowerIsNilWhenAllocationIsZero() {
        let device = USBDevice(registryID: 1, properties: ["UsbPowerSinkAllocation": NSNumber(value: 0)])
        XCTAssertNil(device.powerMilliamps)
        XCTAssertNil(device.powerText)
    }

    // MARK: - Category

    private func interface(number: Int, classCode: Int, protocolCode: Int = 0) -> [String: Any] {
        [
            "bInterfaceNumber": NSNumber(value: number),
            "bInterfaceClass": NSNumber(value: classCode),
            "bInterfaceProtocol": NSNumber(value: protocolCode)
        ]
    }

    private func device(deviceClass: Int, interfaces: [[String: Any]]) -> USBDevice {
        USBDevice(registryID: 1, properties: ["bDeviceClass": NSNumber(value: deviceClass)], interfaces: interfaces)
    }

    func testStorageInterface() {
        let storage = device(deviceClass: 0, interfaces: [interface(number: 0, classCode: 0x08, protocolCode: 0x50)])
        XCTAssertEqual(storage.category, .storage)
        XCTAssertEqual(storage.category?.name, "Storage")
        XCTAssertEqual(storage.symbol, "externaldrive")
    }

    func testHIDProtocolSelectsKeyboardOrMouse() {
        let keyboard = device(deviceClass: 0, interfaces: [interface(number: 0, classCode: 0x03, protocolCode: 1)])
        XCTAssertEqual(keyboard.category, .keyboard)

        let mouse = device(deviceClass: 0, interfaces: [interface(number: 0, classCode: 0x03, protocolCode: 2)])
        XCTAssertEqual(mouse.category, .mouse)
        XCTAssertEqual(mouse.symbol, "computermouse")
    }

    func testHubFromDeviceClass() {
        let hub = device(deviceClass: 0x09, interfaces: [interface(number: 0, classCode: 0x08)])
        XCTAssertEqual(hub.category, .hub)
        XCTAssertTrue(hub.isHub)
    }

    func testInterfaceNumberOrderDecidesCategory() {
        // Listed out of order: interface 0 (audio) wins over interface 1 (HID keyboard),
        // and the unmapped vendor-specific interface 2 is skipped.
        let headset = device(deviceClass: 0, interfaces: [
            interface(number: 1, classCode: 0x03, protocolCode: 1),
            interface(number: 2, classCode: 0xFF),
            interface(number: 0, classCode: 0x01)
        ])
        XCTAssertEqual(headset.category, .audio)
    }

    func testUnknownClassGivesNoCategory() {
        let vendorSpecificInterface = device(deviceClass: 0, interfaces: [interface(number: 0, classCode: 0xFF)])
        XCTAssertNil(vendorSpecificInterface.category)
        XCTAssertEqual(vendorSpecificInterface.symbol, "cable.connector")

        let vendorSpecificDevice = device(deviceClass: 0xFF, interfaces: [])
        XCTAssertNil(vendorSpecificDevice.category)
    }

    func testMiscellaneousDeviceClassFallsThroughToInterfaces() {
        let composite = device(deviceClass: 0xEF, interfaces: [
            interface(number: 0, classCode: 0x0E),
            interface(number: 1, classCode: 0x0E)
        ])
        XCTAssertEqual(composite.category, .videoCamera)
    }

    func testApplePTPDeviceIsAPhone() {
        let ptp = [interface(number: 0, classCode: 0x06, protocolCode: 1)]
        let iphone = USBDevice(registryID: 1, properties: ["idVendor": NSNumber(value: 0x05AC)], interfaces: ptp)
        XCTAssertEqual(iphone.category, .phone)

        let camera = USBDevice(registryID: 2, properties: ["idVendor": NSNumber(value: 0x04A9)], interfaces: ptp)
        XCTAssertEqual(camera.category, .stillCamera)
    }
}
