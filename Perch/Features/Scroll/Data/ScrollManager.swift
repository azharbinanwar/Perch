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

/// How mouse scrolling should be transformed. `active` decides whether the tap runs at all.
struct ScrollConfig: Equatable {
    var reversed = false
    var linear = false        // flat, no acceleration
    var speed: Double = 1     // multiplier (or fixed step when linear)

    var active: Bool { reversed || linear || speed != 1 }
}

final class ScrollManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false
    private var config = ScrollConfig()

    /// Apply a config; starts or stops the tap as needed. Returns false if a transform is
    /// wanted but Accessibility is missing.
    @discardableResult
    func apply(_ newConfig: ScrollConfig) -> Bool {
        config = newConfig
        if config.active {
            return start()
        } else {
            stop()
            return true
        }
    }

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
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)   // fixed loop
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)   // same loop as add
        }
        CFMachPortInvalidate(tap)   // actually kills the port so events stop delivering
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

        // Only transform the mouse — leave the trackpad alone.
        guard !isTrackpad(event) else { return Unmanaged.passUnretained(event) }

        transform(axis: (.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1), of: event)
        transform(axis: (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2), of: event)
        return Unmanaged.passUnretained(event)
    }

    private typealias Axis = (line: CGEventField, point: CGEventField, fixed: CGEventField)

    /// Apply reverse / speed / linear to one axis. Read line+point first, then set all three
    /// (setting the line delta regenerates point, so we overwrite point/fixed after).
    private func transform(axis: Axis, of event: CGEvent) {
        let line = event.getIntegerValueField(axis.line)
        let point = event.getIntegerValueField(axis.point)
        guard line != 0 || point != 0 else { return }

        let fixed = event.getIntegerValueField(axis.fixed)

        var newLine = Double(line)
        var newPoint = Double(point)
        var newFixed = Double(fixed)

        if config.linear {
            // Flat: every notch moves the same amount, regardless of flick speed.
            let dir = Double((point != 0 ? point : line).signum())
            newLine = dir
            newPoint = dir * 10 * config.speed
            newFixed = dir * Double(1 << 16)           // 1.0 line in 16.16 fixed point
        } else {
            newLine *= config.speed
            newPoint *= config.speed
            newFixed *= config.speed                    // scale the original — keeps it consistent
        }
        if config.reversed { newLine = -newLine; newPoint = -newPoint; newFixed = -newFixed }

        event.setIntegerValueField(axis.line, value: Int64(newLine))
        event.setIntegerValueField(axis.point, value: Int64(newPoint))
        event.setIntegerValueField(axis.fixed, value: Int64(newFixed))
    }

    /// A trackpad gesture carries a scroll or momentum phase; a mouse wheel never does —
    /// this holds even for high-resolution mice that report continuous/pixel deltas.
    private func isTrackpad(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
            || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
    }
}
