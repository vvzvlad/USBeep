//
//  ExtraUSBDetails.swift
//  USBNotifier
//
//  Created by Venti on 28/8/25.
//

import SwiftUI
import IOKit

var deviceSpeedMapping: [Int: String] = [
    0: "Low Speed (1.5 Mbps)",
    1: "Full Speed (12 Mbps)",
    2: "High Speed (480 Mbps)",
    3: "Super Speed (5 Gbps)",
    4: "Super Speed+ (10 Gbps)",
    98: "Unknown",
    99: "Built in (∞ Gbps)"
]

func enumerateUSBDevice(device: io_object_t) -> USBDevice? {
    var deviceProperties: Unmanaged<CFMutableDictionary>?
    let propertiesResult = IORegistryEntryCreateCFProperties(device, &deviceProperties, kCFAllocatorDefault, 0)

    guard propertiesResult == KERN_SUCCESS,
          let properties = deviceProperties?.takeRetainedValue() as? [String: Any] else {
        IOObjectRelease(device)
        return nil
    }

    let vendorID = properties["idVendor"] as? Int ?? 0
    let productID = properties["idProduct"] as? Int ?? 0
    let manufacturer = properties["kUSBVendorString"] as? String ?? ""
    let product = properties["kUSBProductString"] as? String ?? ""
    let serialNumber = properties["USB Serial Number"] as? String

    let linkSpeed = properties["Built-In"] as? Bool ?? false ? 99 :
        (properties["Device Speed"] as? Int) ?? 99
    let linkSpeedString = deviceSpeedMapping[linkSpeed] ?? "Unknown"

    let powerAllocated = properties["UsbPowerSinkAllocation"] as? Int ?? 0
    var powerAllocatedString: String?
    if powerAllocated > 0 {
        powerAllocatedString = "\(Double(powerAllocated) / 1000.0 * 5.0) W (\(powerAllocated) mA @ 5V)"
    }

    // Create a new USB device object and add it to the list of devices
    return USBDevice(vendorID: vendorID,
                     productID: productID,
                     manufacturer: manufacturer,
                     product: product,
                     serialNumber: serialNumber,
                     linkSpeed: linkSpeedString,
                     powerAllocated: powerAllocatedString)
}

struct USBItemView: View {
    @Binding var device: USBDevice

    var body: some View {
        VStack(alignment: .leading) {
            Text("ID: \(String(format: "%04X:%04X", device.vendorID, device.productID))")
                .font(.subheadline)
            if let serialNumber = device.serialNumber {
                Text("Serial Number: \(serialNumber)")
                    .font(.subheadline)
            }
            if let linkSpeed = device.linkSpeed {
                if linkSpeed != "" {
                    Text("Link Speed: \(linkSpeed)")
                        .font(.subheadline)
                } else {
                    Text("Link Speed: Unknown")
                        .font(.subheadline)
                }
            }
            if let powerAllocated = device.powerAllocated {
                Text("Power Allocated: \(powerAllocated)")
                    .font(.subheadline)
            }
        }
        .padding()
    }
}

struct ExtraUSBDetails: View {
    @State var devicesList: [USBDevice] = []

    var body: some View {
        VStack {
            ForEach($devicesList) { $device in
                // Make each of these its own highlightable Section
                let deviceFullName = String("\(device.manufacturer) \(device.product)")
                    .trimmingCharacters(in: .whitespaces)

                Section {
                    Button {
                    } label: {
                        Text(deviceFullName.isEmpty ? "Unknown Device" : deviceFullName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    USBItemView(device: $device)
                }
            }
        }
        .padding()
        .onAppear {
            refreshDevices()
            NotificationCenter.default.addObserver(forName: NSNotification.Name("USBDeviceChanged"),
                                                        object: nil, queue: .main) { _ in
                refreshDevices()
            }
        }
    }

    func refreshDevices() {
        devicesList = [USBDevice]()
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        let iterator = UnsafeMutablePointer<io_iterator_t>.allocate(capacity: 1)
        let kernResult = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, iterator)
        let devicePtr = iterator.pointee
        if kernResult != KERN_SUCCESS {
            print("Error: \(kernResult)")
            return
        }
        if devicePtr == 0 {
            print("No USB devices found")
            return
        }
        var device = IOIteratorNext(devicePtr)
        while device != 0 {
            if let usbDevice = enumerateUSBDevice(device: device) {
                devicesList.append(usbDevice)
            }
            // Release the device object
            IOObjectRelease(device)
            device = IOIteratorNext(devicePtr)
        }
    }
}

#Preview {
    ExtraUSBDetails()
}
