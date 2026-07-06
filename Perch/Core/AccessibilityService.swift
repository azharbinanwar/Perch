//
//  AccessibilityService.swift
//  Perch
//
//  One owner for the Accessibility (AXIsProcessTrusted) permission — status, prompt, and the
//  deep link — instead of scattering AXIsProcessTrusted() calls across the app.
//
//  Two ways to read status, on purpose:
//   • `trusted` — a live SYNC read (cheap; reads TCC's cached value). Engines call this on each
//     event to gate work — if it's false, do nothing and release. No async, no listener.
//   • `isTrusted` — an @Observable snapshot for the UI. It updates only when `refresh()` is
//     called (e.g. when a settings view appears), so SwiftUI redraws the granted/not-granted
//     state. We deliberately do NOT poll — the UI just re-checks when it rebuilds.
//

import Observation
import ApplicationServices
import AppKit

@Observable
final class AccessibilityService {
    static let shared = AccessibilityService()

    /// Observable snapshot for the UI. Refreshed on demand via `refresh()`, never polled.
    private(set) var isTrusted: Bool

    private init() { isTrusted = AXIsProcessTrusted() }

    /// Live, synchronous status — safe and cheap to call on every event in an engine's hot path.
    var trusted: Bool { AXIsProcessTrusted() }

    /// Re-read the current status into `isTrusted` so any bound UI updates. Returns the value.
    @discardableResult
    func refresh() -> Bool {
        isTrusted = AXIsProcessTrusted()
        return isTrusted
    }

    /// Show the system Accessibility prompt (fires only once per launch) and open the pane —
    /// the deep link always lands there, so a repeat tap never feels dead.
    func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        openSettings()
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
