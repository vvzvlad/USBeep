//
//  MenuBarView.swift
//  USBNotifier
//
//  Created by Venti on 12/01/2024.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var storage = Storage.Observable()
    @ObservedObject var autostart = LaunchAtStartup.Observable()

    @State private var possibleDetectionDelays = [1, 5, 10, 60]
    @ObservedObject private var detectorStatus = USBDetector.Observable()

    var body: some View {
        VStack {
            Text(String(localized: "usb.service.status:") + " " +
                 (detectorStatus.status ? String(localized: "usb.service.running")
                                            : String(localized: "usb.service.paused")))

            Divider()

            if !detectorStatus.status {
                Button {
                    detectorStatus.status = true
                } label: {
                    Label("usb.service.start", systemImage: "play")
                }
            } else {
                Button {
                    detectorStatus.status = false
                } label: {
                    Label("usb.service.pause", systemImage: "pause")
                }
            }

            Divider()

            Menu {
                Toggle(isOn: $storage.connectionSound) {
                    Text("usb.service.makeSound")
                }

                Toggle(isOn: $storage.ephemeralNotifs) {
                    Text("usb.service.ephemeral")
                }

                Toggle(isOn: $autostart.status) {
                    Text("usb.service.autostart")
                }
            }
            label: {
                Label("settings", systemImage: "gearshape")
            }

            Menu {
                ExtraUSBDetails()
            } label: {
                Label("extraUSBdetails", systemImage: "info")
            }

            Button("app.quit") {
                exit(0)
            }
        }
    }
}

#Preview {
    MenuBarView()
}
