//
//  MouseDebounceManager.swift
//  Perch
//
//  Fixes a worn mouse switch that fires twice on one press: swallows a second click of the
//  same button that lands within a short window. The window is well below the intentional
//  double-click speed, so real double-clicks still work. Requires Accessibility.
//

import CoreGraphics
import Foundation

final class MouseDebounceManager {
    /// The Mouse module's master switch (pushed by the ViewModel) — separate from `enabled`,
    /// which is the debounce feature's own on/off. Master off = the whole module is paused.
    var mouseModuleEnabled = false
    private var enabled = false
    private var threshold: Double = 0.05    // seconds

    private var lastDown: [Int64: Double] = [:]
    private var swallowUp: Set<Int64> = []

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func apply(enabled: Bool, thresholdMs: Double) {
        self.enabled = enabled
        self.threshold = max(0, thresholdMs) / 1000
        stop()
        if enabled { start() }
    }

    // MARK: - Tap

    @discardableResult
    private func start() -> Bool {
        guard eventTap == nil, AccessibilityService.shared.trusted else { return false }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MouseDebounceManager>.fromOpaque(refcon).takeUnretainedValue()
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
        lastDown = [:]
        swallowUp = []
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables the tap on timeout/revoke; re-enable + pass. Never call Accessibility here.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if !mouseModuleEnabled { return Unmanaged.passUnretained(event) }   // 1) master toggle
        if !AccessibilityService.shared.isTrusted {                         // 2) cached permission
            NSLog("[Perch:Acc] debounce: cached permission off → markAllOff")
            AccessibilityService.shared.markAllOff()
            return Unmanaged.passUnretained(event)
        }
        let button: Int64
        switch type {
        case .leftMouseDown, .leftMouseUp:   button = 0
        case .rightMouseDown, .rightMouseUp: button = 1
        default:                             button = event.getIntegerValueField(.mouseEventButtonNumber)
        }

        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let now = ProcessInfo.processInfo.systemUptime
            let previous = lastDown[button] ?? 0
            lastDown[button] = now
            if now - previous < threshold {          // too soon → a bounce
                swallowUp.insert(button)
                return nil
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if swallowUp.contains(button) {          // drop the bounced click's release too
                swallowUp.remove(button)
                return nil
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
