//
//  AutoScrollManager.swift
//  Perch
//
//  Windows-style auto-scroll. Long-press the trigger button to engage (a quick click passes
//  through untouched, so middle-click "open in new tab" still works); then move to scroll.
//  Keep holding to scroll while held, or release to latch and scroll hands-free. Any click stops.
//  macOS has no equivalent. Requires Accessibility permission.
//

import CoreGraphics
import Foundation

final class AutoScrollManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchSourceTimer?

    private var enabled = false
    private var triggerButton = 2          // middle by default
    private var sensitivity: Double = 1

    private var active = false             // scroll mode engaged & running
    private var latched = false            // released after engaging → keeps scrolling until a click
    private var origin = CGPoint.zero      // where the press started (the anchor)
    private var current = CGPoint.zero
    private var pendingEngage: DispatchWorkItem?   // fires after a long press if still held

    private let indicator = AutoScrollIndicator()

    // Hold the trigger this long (still down) to engage; a quicker release passes the click through.
    private let longPressDelay: TimeInterval = 0.4

    // Below this many pixels from the origin, don't scroll — gives a stable neutral zone.
    private let deadZone: CGFloat = 10
    // Base pixels-per-tick per pixel of displacement, at 60 Hz. Small so it feels smooth.
    private let gain: CGFloat = 0.06

    /// Apply settings; starts or stops the tap. Returns false if enabled but Accessibility missing.
    @discardableResult
    func apply(enabled: Bool, triggerButton: Int, sensitivity: Double) -> Bool {
        self.triggerButton = triggerButton
        self.sensitivity = sensitivity
        self.enabled = enabled
        if enabled {
            return start()
        } else {
            stop()
            return true
        }
    }

    @discardableResult
    private func start() -> Bool {
        guard eventTap == nil else { return true }
        guard Permissions.isAccessibilityTrusted else { return false }

        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .mouseMoved, .otherMouseDragged, .leftMouseDown, .rightMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<AutoScrollManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func stop() {
        end()
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        switch type {
        case .otherMouseDown where button == triggerButton:
            if active { end(); return nil }         // click while scrolling = dismiss (swallowed)
            scheduleEngage(at: event.location)      // arm the long press…
            return Unmanaged.passUnretained(event)  // …but let the click through for now

        case .otherMouseUp where button == triggerButton:
            if active { latched = true; return nil }   // released after engaging → latch, swallow
            cancelEngage()                              // quick click → never engaged
            return Unmanaged.passUnretained(event)      // let it through (opens tab, etc.)

        // Any other button press while scrolling ends it (dismiss, swallowed).
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if active { end(); return nil }
            return Unmanaged.passUnretained(event)

        case .mouseMoved, .otherMouseDragged:
            if active { current = event.location }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func scheduleEngage(at point: CGPoint) {
        cancelEngage()
        origin = point
        let work = DispatchWorkItem { [weak self] in self?.engage() }
        pendingEngage = work
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDelay, execute: work)
    }

    private func cancelEngage() {
        pendingEngage?.cancel()
        pendingEngage = nil
    }

    private func engage() {
        pendingEngage = nil
        current = origin
        active = true
        latched = false
        indicator.show(at: origin)
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func end() {
        cancelEngage()
        active = false
        latched = false
        indicator.hide()
        stopScrolling()
    }

    private func stopScrolling() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard active else { return }
        let dy = displacement(current.y - origin.y)
        let dx = displacement(current.x - origin.x)
        indicator.update(dx: dx, dy: dy)       // point the caret (idle dot inside the dead-zone)
        guard dy != 0 || dx != 0 else { return }

        // wheel1 = vertical, wheel2 = horizontal. Positive wheel1 scrolls content up, so flip dy.
        guard let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                   wheel1: Int32(-dy), wheel2: Int32(-dx), wheel3: 0) else { return }
        scroll.post(tap: .cgSessionEventTap)
    }

    /// Turn a raw offset into a per-tick pixel delta: zero inside the dead-zone, then scaled.
    private func displacement(_ raw: CGFloat) -> CGFloat {
        let magnitude = abs(raw)
        guard magnitude > deadZone else { return 0 }
        return (raw - CGFloat(raw.sign == .minus ? -deadZone : deadZone)) * gain * CGFloat(sensitivity)
    }
}
