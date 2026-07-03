//
//  PointerManager.swift
//  Perch
//
//  Controls system pointer (mouse) acceleration via IOKit — the thing macOS won't let you
//  turn off in its GUI. A negative value = disabled (flat 1:1 tracking); 0…20 = acceleration
//  amount. This is a live system setting (persists until changed or logout), so we restore
//  the captured default when the user turns the override off or Perch quits.
//

import Foundation
import IOKit
import IOKit.hidsystem

final class PointerManager {
    private let accelerationKey = "HIDMouseAcceleration" as CFString

    /// Set mouse acceleration. Negative disables it (1:1).
    func setAcceleration(_ value: Double) {
        withConnection { IOHIDSetAccelerationWithKey($0, accelerationKey, value) }
    }

    /// Current system acceleration, for capturing/restoring the default.
    func acceleration() -> Double? {
        var value = 0.0
        var ok = false
        withConnection {
            if IOHIDGetAccelerationWithKey($0, accelerationKey, &value) == KERN_SUCCESS { ok = true }
        }
        return ok ? value : nil
    }

    private func withConnection(_ body: (io_connect_t) -> Void) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connect) }
        body(connect)
    }
}
