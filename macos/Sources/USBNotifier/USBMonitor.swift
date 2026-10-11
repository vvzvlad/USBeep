import Foundation
import IOKit

enum USBEvent {
    case connected
    case disconnected
}

/// Watches IOUSBHostDevice services: keeps the live device list and, after a
/// 1 s debounce, notifies and plays a sound for each batch of changes.
@MainActor
final class USBMonitor: ObservableObject {
    @Published private(set) var devices: [USBDevice] = []

    private static let className = "IOUSBHostDevice"
    private static let debounceInterval: TimeInterval = 1

    private let notifier: Notifier
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = IO_OBJECT_NULL
    private var terminatedIterator: io_iterator_t = IO_OBJECT_NULL

    /// Last known state of every present device. A terminated service may have
    /// lost its properties, so disconnect notifications are built from here.
    private var cache: [UInt64: USBDevice] = [:]
    private var pendingConnected: [USBDevice] = []
    private var pendingDisconnected: [USBDevice] = []
    private var debounceTimer: Timer?

    init(notifier: Notifier) {
        self.notifier = notifier
    }

    /// Subscribes to IOKit match/terminate notifications on the main run loop.
    /// The monitor lives for the whole app lifetime, so the unretained refcon
    /// handed to IOKit never dangles and nothing is torn down.
    func start() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        notificationPort = port
        // Common modes, so events keep coming while a menu (e.g. a Picker) is tracking.
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
                           .commonModes)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        // Each call consumes its matching dictionary, hence a fresh one per call.
        // First-match fires once per service instance; plain "matched" may fire
        // again when a present device re-registers and would post a false "Connected".
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching(Self.className),
                                         { refcon, iterator in
                                             guard let refcon else { return }
                                             let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                                             MainActor.assumeIsolated { monitor.handleMatched(iterator) }
                                         },
                                         refcon, &matchedIterator)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching(Self.className),
                                         { refcon, iterator in
                                             guard let refcon else { return }
                                             let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                                             MainActor.assumeIsolated { monitor.handleTerminated(iterator) }
                                         },
                                         refcon, &terminatedIterator)

        // The notifications are armed only once their iterators are drained.
        // Devices already present are skipped here and enter the list silently via refresh().
        Self.forEachService(in: matchedIterator) { _ in }
        Self.forEachService(in: terminatedIterator) { _ in }
        refresh()
    }

    /// Re-reads all present devices into `devices` and the cache.
    func refresh() {
        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(Self.className),
                                           &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        var found: [USBDevice] = []
        Self.forEachService(in: iterator) { found.append(Self.readDevice($0)) }
        // Entries are dropped only on termination, so a refresh racing with a
        // pending termination callback cannot lose the cached device.
        for device in found {
            cache[device.id] = device
        }

        let sorted = found.sorted { lhs, rhs in
            switch lhs.name.localizedStandardCompare(rhs.name) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return lhs.id < rhs.id
            }
        }
        if sorted != devices {
            devices = sorted
        }
    }

    // MARK: - IOKit callbacks

    private func handleMatched(_ iterator: io_iterator_t) {
        Self.forEachService(in: iterator) { service in
            let device = Self.readDevice(service)
            cache[device.id] = device
            pendingConnected.append(device)
        }
        scheduleFlush()
    }

    private func handleTerminated(_ iterator: io_iterator_t) {
        Self.forEachService(in: iterator) { service in
            let id = Self.registryID(of: service)
            let cached = cache.removeValue(forKey: id)
            // Came and went within one debounce window (contact bounce, a quick
            // plug-unplug): report neither the connect nor the disconnect.
            if let index = pendingConnected.firstIndex(where: { $0.id == id }) {
                pendingConnected.remove(at: index)
                return
            }
            pendingDisconnected.append(cached ?? Self.readDevice(service))
        }
        scheduleFlush()
    }

    // MARK: - Debounce

    private func scheduleFlush() {
        debounceTimer?.invalidate()
        let timer = Timer(timeInterval: Self.debounceInterval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
        RunLoop.main.add(timer, forMode: .common)
        debounceTimer = timer
    }

    private func flush() {
        debounceTimer = nil
        refresh()

        // Re-read state wins for connected devices: speed and power may only
        // appear some time after the match notification.
        let connected = pendingConnected.map { cache[$0.id] ?? $0 }
        let disconnected = pendingDisconnected
        pendingConnected = []
        pendingDisconnected = []

        if !disconnected.isEmpty {
            notifier.post(.disconnected, devices: disconnected)
            // A mixed batch plays only the connect sound: two sounds at once are a mess.
            if connected.isEmpty {
                SoundPlayer.play(for: .disconnected)
            }
        }
        if !connected.isEmpty {
            notifier.post(.connected, devices: connected)
            SoundPlayer.play(for: .connected)
        }
    }

    // MARK: - IOKit helpers

    /// Calls `body` for every object in the iterator and releases each one.
    private static func forEachService(in iterator: io_iterator_t, _ body: (io_object_t) -> Void) {
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            body(service)
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private static func registryID(of service: io_service_t) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &id)
        return id
    }

    private static func readDevice(_ service: io_service_t) -> USBDevice {
        USBDevice(registryID: registryID(of: service),
                  properties: properties(of: service),
                  interfaces: interfaceProperties(of: service))
    }

    private static func properties(of entry: io_registry_entry_t) -> [String: Any] {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0)
        return unmanaged?.takeRetainedValue() as? [String: Any] ?? [:]
    }

    /// Properties of the device's IOUSBHostInterface children (used for the category).
    private static func interfaceProperties(of service: io_service_t) -> [[String: Any]] {
        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard IORegistryEntryGetChildIterator(service, kIOServicePlane, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var interfaces: [[String: Any]] = []
        forEachService(in: iterator) { child in
            if IOObjectConformsTo(child, "IOUSBHostInterface") != 0 {
                interfaces.append(properties(of: child))
            }
        }
        return interfaces
    }
}
