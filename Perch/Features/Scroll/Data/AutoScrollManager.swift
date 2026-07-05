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

/// One profile's auto-scroll settings, resolved by the app under the cursor at trigger time.
struct AutoScrollConfig: Equatable {
    var on = false
    var button = 2
    var speed: Double = 1
}

final class AutoScrollManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchSourceTimer?

    // Per-app configs — like scrolling, auto-scroll is cursor-based: the app under the
    // pointer at trigger time decides whether it engages, with which button, how fast.
    private var defaultConfig = AutoScrollConfig()
    private var appConfigs: [String: AutoScrollConfig] = [:]

    private var sensitivity: Double = 1    // the engaged session's speed (from the anchor app)
    private var engagedButton = 2          // the engaged session's trigger button

    private var active = false             // scroll mode engaged & running
    private var latched = false            // released after engaging → keeps scrolling until a click
    private var origin = CGPoint.zero      // where the press started (the anchor)
    private var current = CGPoint.zero
    private var anchorBounds: CGRect?      // the anchored window — leaving it ends auto-scroll
    private var pendingEngage: DispatchWorkItem?   // fires after a long press if still held

    private let indicator = AutoScrollIndicator()

    // Hold the trigger this long (still down) to engage; a quicker release passes the click through.
    private let longPressDelay: TimeInterval = 0.4

    // Below this many pixels from the origin, don't scroll — gives a stable neutral zone.
    private let deadZone: CGFloat = 10
    // Base pixels-per-tick per pixel of displacement, at 60 Hz. Small so it feels smooth.
    private let gain: CGFloat = 0.06

    /// Apply the Default + per-app configs; starts or stops the tap as needed.
    /// Returns false if wanted but Accessibility is missing.
    @discardableResult
    func apply(default defaultConfig: AutoScrollConfig, perApp: [String: AutoScrollConfig]) -> Bool {
        self.defaultConfig = defaultConfig
        self.appConfigs = perApp
        if defaultConfig.on || perApp.values.contains(where: \.on) {
            return start()
        } else {
            stop()
            return true
        }
    }

    /// The config for the app under a point (Default when the app has no profile).
    private func config(at point: CGPoint) -> AutoScrollConfig {
        guard !appConfigs.isEmpty else { return defaultConfig }
        guard let bundleID = WindowAtPoint.info(under: point)?.bundleID,
              let config = appConfigs[bundleID] else { return defaultConfig }
        return config
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
        case .otherMouseDown:
            if active { end(); return nil }         // click while scrolling = dismiss (swallowed)
            // Cursor-based: the app under the pointer decides if/how auto-scroll triggers here.
            let config = self.config(at: event.location)
            if config.on && button == config.button {
                sensitivity = config.speed
                engagedButton = button
                scheduleEngage(at: event.location)  // arm the long press…
            }
            return Unmanaged.passUnretained(event)  // …but let the click through for now

        case .otherMouseUp where button == engagedButton:
            if active { latched = true; return nil }   // released after engaging → latch, swallow
            cancelEngage()                              // quick click → never engaged
            return Unmanaged.passUnretained(event)      // let it through (opens tab, etc.)

        // Any other button press while scrolling ends it (dismiss, swallowed).
        case .leftMouseDown, .rightMouseDown:
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
        anchorBounds = WindowAtPoint.info(under: origin)?.bounds   // auto-scroll lives in this window
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
        anchorBounds = nil
        indicator.hide()
        stopScrolling()
    }

    private func stopScrolling() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard active else { return }

        // Stepping out of the anchored window ends the gesture — no invisible background scrolling.
        if let bounds = anchorBounds, !bounds.contains(current) { end(); return }

        let dy = displacement(current.y - origin.y)
        let dx = displacement(current.x - origin.x)
        indicator.update(dx: dx, dy: dy)       // point the caret (idle dot inside the dead-zone)
        guard dy != 0 || dx != 0 else { return }

        // wheel1 = vertical, wheel2 = horizontal. Positive wheel1 scrolls content up, so flip dy.
        // No explicit location — a posted location also drags the pointer (60Hz cursor jerking).
        // Anchoring is enforced by the bounds check above instead: while scrolling, the cursor
        // can only be inside the anchored window, so that's where the events land.
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
