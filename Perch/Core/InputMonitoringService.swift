//
//  InputMonitoringService.swift
//  Perch
//
//  One owner for the Input Monitoring (IOHID listen) permission — the sibling of
//  AccessibilityService. Accessibility lets us CONTROL input (active taps); Input Monitoring
//  lets us OBSERVE raw devices (IOHIDDeviceOpen — mouse detection, listen-only watching).
//  Same shape: sync `trusted` for engine gating, observable `isTrusted` for UI via refresh().
//
//  IMPORTANT: `request()` is the only place the system prompt may fire — engines must gate on
//  `trusted` and never call IOHID opens when it's false (background prompt storms stall the app).
//

import Observation
import IOKit.hid
import AppKit

@Observable
final class InputMonitoringService {
    static let shared = InputMonitoringService()

    /// Observable snapshot for the UI. Refreshed on demand via `refresh()`, never polled.
    private(set) var isTrusted: Bool

    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    private init() {
        isTrusted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        // Re-sync when the user returns to Perch after granting in System Settings.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    /// Live, synchronous status — cheap; safe to check before any IOHID open.
    var trusted: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }

    /// Re-read the current status into `isTrusted` so any bound UI updates. Returns the value.
    @discardableResult
    func refresh() -> Bool {
        isTrusted = trusted
        return isTrusted
    }

    /// Show the system prompt (once per launch) and open the pane so a repeat tap never feels dead.
    func request() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openSettings()
    }

    /// Open System Settings → Privacy & Security → Input Monitoring.
    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
