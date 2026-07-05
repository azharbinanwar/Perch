//
//  KeyChordRecorder.swift
//  Perch
//
//  Records one key chord by *swallowing* it — so recording e.g. ⌘⇧4 captures the combo
//  instead of firing the screenshot. Requires Accessibility. Reusable (mouse custom
//  keystroke now; keyboard remapper later).
//

import CoreGraphics
import Foundation

final class KeyChordRecorder {
    /// Reports (keyCode, CGEventFlags raw) on the main thread for the first key pressed.
    var onCapture: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    /// Hyper-key support (optional — nil leaves behavior exactly as before). Returns nil when
    /// the hyper feature is off; otherwise the flags to add when the hyper key is held right now.
    var hyperFlags: (() -> CGEventFlags?)?

    /// True when the last capture happened while the hyper key was held (set synchronously).
    private(set) var lastCaptureViaHyper = false

    private let hyperKeyCode = 79   // F18 — what Caps Lock becomes while Hyper is enabled

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil, Permissions.isAccessibilityTrusted else { return false }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<KeyChordRecorder>.fromOpaque(refcon).takeUnretainedValue()
                    .handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Hyper key: treat it like a modifier, not a key. Pass it through (the hyper engine
        // tracks held-state and swallows it) and don't capture it. Only when the feature is on.
        if code == hyperKeyCode, hyperFlags?() != nil {
            return Unmanaged.passUnretained(event)
        }

        var flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        let extra = hyperFlags?() ?? []
        flags.formUnion(extra)                    // hyper held → record with ⌘⌥⌃(⇧)
        lastCaptureViaHyper = !extra.isEmpty
        let mods = flags.rawValue
        DispatchQueue.main.async { self.onCapture?(code, mods) }
        return nil   // swallow — the recorded combo must not actually fire
    }
}
