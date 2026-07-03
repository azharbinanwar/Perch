//
//  MouseDeviceMonitor.swift
//  Perch
//
//  Lists connected mice via IOKit HID and reports changes. IOHIDManager's add/removal
//  callbacks are unreliable across macOS versions (removal often doesn't fire), so we use
//  them only as a fast hint and re-enumerate on a light poll — re-querying after a removal
//  settles gives the correct list. Trackpads (built-in and Magic) are filtered out.
//

import Foundation
import IOKit
import IOKit.hid

final class MouseDeviceMonitor {
    /// Called on the main thread whenever the set of connected mice changes.
    var onChange: (([MouseDevice]) -> Void)?

    private var manager: IOHIDManager?
    private var pollTimer: DispatchSourceTimer?
    private var resyncWork: DispatchWorkItem?
    private var last: [MouseDevice] = []

    func start() {
        guard manager == nil else { resync(); return }
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
        ]
        IOHIDManagerSetDeviceMatching(m, match as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let cb: IOHIDDeviceCallback = { context, _, _, _ in
            guard let context else { return }
            Unmanaged<MouseDeviceMonitor>.fromOpaque(context).takeUnretainedValue().scheduleResync()
        }
        IOHIDManagerRegisterDeviceMatchingCallback(m, cb, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(m, cb, ctx)
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = m

        // Safety net: re-enumerate periodically in case a callback never fires.
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 2, repeating: 2)
        t.setEventHandler { [weak self] in self?.resync() }
        t.resume()
        pollTimer = t

        resync()
    }

    /// A callback fired — re-enumerate shortly after so a removal has time to settle.
    private func scheduleResync() {
        resyncWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.resync() }
        resyncWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func resync() {
        guard let m = manager, let set = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> else {
            deliver([]); return
        }
        var devices: [MouseDevice] = []
        for device in set {
            // Skip the built-in trackpad and Magic Trackpad (they report as mouse-usage devices).
            let builtIn = IOHIDDeviceGetProperty(device, "Built-In" as CFString)
            if (builtIn as? Bool) == true || ((builtIn as? Int) ?? 0) != 0 { continue }
            let name = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "Mouse"
            if name.localizedCaseInsensitiveContains("trackpad") { continue }
            let transport = (IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String) ?? ""
            if transport.caseInsensitiveCompare("SPI") == .orderedSame { continue }
            devices.append(MouseDevice(name: name, transport: transport, buttons: buttonCount(device)))
        }
        deliver(devices.sorted { $0.name < $1.name })
    }

    /// Distinct button usages reported by the device (a rough physical button count).
    private func buttonCount(_ device: IOHIDDevice) -> Int {
        let match: [String: Any] = [kIOHIDElementUsagePageKey: kHIDPage_Button]
        guard let elements = IOHIDDeviceCopyMatchingElements(device, match as CFDictionary, 0) as? [IOHIDElement] else { return 0 }
        return Set(elements.map { IOHIDElementGetUsage($0) }).count
    }

    private func deliver(_ devices: [MouseDevice]) {
        guard devices != last else { return }   // only notify on real changes
        last = devices
        onChange?(devices)
    }
}
