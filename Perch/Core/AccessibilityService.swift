//
//  AccessibilityService.swift
//  Perch
//
//  One owner for the Accessibility (AXIsProcessTrusted) permission — status, prompt, deep link,
//  and grant detection — instead of scattering AXIsProcessTrusted() calls across the app.
//
//  Status is read two ways, on purpose:
//   • `trusted` — a live SYNC read (asks the OS). Use sparingly; never on a per-event hot path.
//   • `isTrusted` — an @Observable in-memory snapshot the UI binds to. It changes only when we
//     re-sync from the OS, at controlled moments — never polled continuously.
//
//  We re-sync at exactly three moments (never per event, never persisted to disk — the OS owns it):
//   1. app becomes active   (user returns after granting/revoking in System Settings)
//   2. `refresh()` on demand (a gate/tab appears)
//   3. a bounded watcher started by `request()` — flips the UI the instant the user grants,
//      even if they never refocus the app, then tears itself down.
//

import Observation
import ApplicationServices
import AppKit

@Observable
final class AccessibilityService {
    static let shared = AccessibilityService()

    /// Observable in-memory snapshot for the UI. Re-synced at controlled moments, never polled forever.
    private(set) var isTrusted: Bool

    /// "Turn me off" actions from each module. When a check finds Accessibility missing, we call
    /// them all — the service is the ONE place that marks modules off. ViewModels are app-lived, so
    /// this is a plain list (no tokens/removal).
    @ObservationIgnored private var disablers: [() -> Void] = []
    @ObservationIgnored private var grantWatcher: Task<Void, Never>?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    /// A module registers how to switch itself off (e.g. `{ [weak vm] in vm?.setEnabled(false) }`).
    func registerGate(_ disable: @escaping () -> Void) { disablers.append(disable) }

    /// Switch every registered module off. Called when a check finds Accessibility missing —
    /// from a UI moment (`refresh`) or from an engine that noticed the cached flag is off.
    func markAllOff() {
        NSLog("[Perch:Acc] markAllOff — switching \(disablers.count) module(s) off")
        disablers.forEach { $0() }
    }

    private init() {
        isTrusted = AXIsProcessTrusted()
        // Baseline recheck: when the user comes back to Perch (e.g. after System Settings), re-sync.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    /// Live, synchronous status straight from the OS. Use for one-off checks (e.g. engine `start()`),
    /// NOT on a per-event hot path.
    var trusted: Bool { AXIsProcessTrusted() }

    /// Re-sync `isTrusted` from the OS — the UI-moment check (launch, app active, menu, clipboard).
    /// If it's off, mark every module off. Bound UI (`isTrusted`) redraws automatically. Returns it.
    @discardableResult
    func refresh() -> Bool {
        let now = AXIsProcessTrusted()
        if now != isTrusted {
            isTrusted = now
            NSLog("[Perch:Acc] permission changed → \(now ? "GRANTED" : "DENIED")")
            if now { grantWatcher?.cancel(); grantWatcher = nil }   // granted → stop watching
        }
        if !now { markAllOff() }   // off → the service switches every module off
        return now
    }

    /// Prompt (once per launch) + open the pane, then start a bounded watcher so the UI unblocks
    /// the moment the user grants — even if they don't click back to Perch.
    func request() {
        NSLog("[Perch:Acc] request — prompting + opening Settings + watching for grant")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        openSettings()
        startGrantWatch()
    }

    /// A short-lived poll that flips `isTrusted` the instant the grant lands, then self-destructs.
    /// Bounded (~60s) so it can never leak or run as a permanent stream.
    private func startGrantWatch() {
        guard !isTrusted else { return }
        grantWatcher?.cancel()
        grantWatcher = Task { @MainActor [weak self] in
            for _ in 0 ..< 60 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if self?.refresh() == true { return }   // granted → refresh() stops the watcher
            }
        }
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
