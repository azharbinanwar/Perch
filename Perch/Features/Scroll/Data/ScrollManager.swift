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
    var smooth = false        // glide wheel ticks instead of jumping

    var active: Bool { reversed || linear || speed != 1 || smooth }
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

        // Our own glide events pass through untouched (or they'd be re-smoothed forever).
        if event.getIntegerValueField(.eventSourceUnixProcessID) == selfPID {
            return Unmanaged.passUnretained(event)
        }

        // Only transform the mouse — leave the trackpad alone.
        guard !isTrackpad(event) else { return Unmanaged.passUnretained(event) }

        transform(axis: (.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1), of: event)
        transform(axis: (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2), of: event)

        // Smooth: swallow the chunky step and glide the same distance over the next frames.
        if config.smooth { return smoothed(event) }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Smooth scrolling (glide)

    private let selfPID = Int64(ProcessInfo.processInfo.processIdentifier)
    private var pendingY = 0.0        // pixels left to glide (pixel-scrolling apps)
    private var pendingX = 0.0
    private var pendingLinesY = 0.0   // exact original lines left to emit (line-based apps like Terminal)
    private var pendingLinesX = 0.0
    private var lineFracY = 0.0       // fractional line carry between frames
    private var lineFracX = 0.0
    private var glideTimer: Timer?

    /// Add the (already reversed/scaled) step to the glide target and swallow the original.
    /// Pixels get a minimum distance so a slow tick's ~10px glide is visible; the LINE total is
    /// carried exactly, so line-based apps (Terminal) still get precisely 1 line per tick.
    private func smoothed(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pointY = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let pointX = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        let lineY = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineX = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        pendingY += minimumStep(pointY != 0 ? pointY : lineY * 10)
        pendingX += minimumStep(pointX != 0 ? pointX : lineX * 10)
        pendingLinesY += lineY
        pendingLinesX += lineX

        if glideTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.glideTick() }
            RunLoop.main.add(timer, forMode: .common)
            glideTimer = timer
        }
        return nil
    }

    /// A slow tick reports ~10px — floor it to 40px so the glide is actually visible.
    private func minimumStep(_ delta: Double) -> Double {
        guard delta != 0 else { return 0 }
        return abs(delta) < 40 ? (delta > 0 ? 40 : -40) : delta
    }

    /// Each frame emits ~14% of what's left (eased glide, ~300ms per notch), minimum 1px.
    private func glideTick() {
        let dy = take(&pendingY)
        let dx = take(&pendingX)
        let linesY = takeLines(&pendingLinesY, frac: &lineFracY, finishing: dy == 0)
        let linesX = takeLines(&pendingLinesX, frac: &lineFracX, finishing: dx == 0)
        if dy == 0 && dx == 0 && linesY == 0 && linesX == 0 {
            glideTimer?.invalidate()
            glideTimer = nil
            lineFracY = 0; lineFracX = 0
            return
        }

        // Build the event empty, then fill each field family ourselves: point deltas carry the
        // pixel glide; line + fixed-point carry the exact per-tick line budget (no per-frame
        // rounding up — that's what made Terminal fly 50 lines per tick).
        let event = CGEvent(scrollWheelEvent2Source: CGEventSource(stateID: .combinedSessionState),
                            units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)
        event?.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(linesY))
        event?.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(linesX))
        event?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(dy))
        event?.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(dx))
        event?.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Int64(Double(linesY) * 65536))
        event?.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Int64(Double(linesX) * 65536))
        event?.post(tap: .cgSessionEventTap)
    }

    private func take(_ pending: inout Double) -> Int32 {
        guard abs(pending) >= 0.5 else { pending = 0; return 0 }
        var step = pending * 0.14
        if abs(step) < 1 { step = pending > 0 ? 1 : -1 }
        let out = Int32(step.rounded())
        pending -= Double(out)
        return out
    }

    /// Ease the line budget out alongside the pixels; whole lines only, fraction carried over.
    /// When the pixel glide is done (`finishing`), flush whatever line remainder is left.
    private func takeLines(_ pending: inout Double, frac: inout Double, finishing: Bool) -> Int32 {
        if finishing {
            let out = Int32((pending + frac).rounded())
            pending = 0; frac = 0
            return out
        }
        let step = pending * 0.14
        pending -= step
        frac += step
        let out = Int32(frac.rounded(.towardZero))
        frac -= Double(out)
        return out
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
