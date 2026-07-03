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
        let mods = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).rawValue
        DispatchQueue.main.async { self.onCapture?(code, mods) }
        return nil   // swallow — the recorded combo must not actually fire
    }
}
