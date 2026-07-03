//
//  MouseButtonMonitor.swift
//  Perch
//
//  Manager. Listen-only CGEventTap on mouse-down events; reports which button number was
//  pressed. Used by the detector to discover which buttons macOS actually receives.
//  Requires Accessibility permission. Registered in ServiceLocator.
//

import CoreGraphics
import Foundation

final class MouseButtonMonitor {
    /// Called on the main thread with the pressed button number (0 = left, 1 = right, …).
    var onButton: ((Int) -> Void)?
    /// Called when a key fires while detecting — some mice send extra buttons as keystrokes.
    var onKey: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard Permissions.isAccessibilityTrusted else { return false }

        let mask = CGEventMask(
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue))   // some buttons emit a keystroke
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,   // observe only — never swallow the click
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon {
                    Unmanaged<MouseButtonMonitor>.fromOpaque(refcon).takeUnretainedValue()
                        .handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        switch type {
        case .leftMouseDown:  report(button: 0)
        case .rightMouseDown: report(button: 1)
        case .otherMouseDown: report(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        case .keyDown:
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let mods = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).rawValue
            DispatchQueue.main.async { self.onKey?(code, mods) }
        default: return
        }
    }

    private func report(button: Int) {
        DispatchQueue.main.async { self.onButton?(button) }
    }
}
