//
//  ScrollManager.swift
//  Perch
//
//  Manager. CGEventTap on scroll events. Reverses MOUSE scroll only —
//  trackpad (continuous/pixel) passes through untouched.
//  Requires Accessibility permission.
//

import CoreGraphics
import Foundation

final class ScrollManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard Permissions.isAccessibilityTrusted else { return false }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<ScrollManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables the tap on timeout/user-input; re-enable and pass through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

        // Trackpad scroll is continuous (pixel/momentum); mouse wheel is line-based.
        // Only reverse the mouse.
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else {
            return Unmanaged.passUnretained(event)
        }

        for field in [CGEventField.scrollWheelEventDeltaAxis1,
                      .scrollWheelEventDeltaAxis2,
                      .scrollWheelEventPointDeltaAxis1,
                      .scrollWheelEventPointDeltaAxis2,
                      .scrollWheelEventFixedPtDeltaAxis1,
                      .scrollWheelEventFixedPtDeltaAxis2] {
            let value = event.getIntegerValueField(field)
            if value != 0 { event.setIntegerValueField(field, value: -value) }
        }
        return Unmanaged.passUnretained(event)
    }
}
