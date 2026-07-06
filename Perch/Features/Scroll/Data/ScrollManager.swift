//
//  ScrollManager.swift
//  Perch
//
//  Manager. CGEventTap on scroll events. Reverses MOUSE scroll only —
//  trackpad (continuous/pixel) passes through untouched.
//  Requires Accessibility permission.
//

import AppKit
import CoreGraphics
import Foundation

/// How mouse scrolling should be transformed. `active` decides whether the tap runs at all.
struct ScrollConfig: Equatable {
    var reversed = false
    var linear = false        // flat, no acceleration
    var speed: Double = 1     // multiplier (or fixed step when linear)
    var smooth = false        // glide wheel ticks instead of jumping
    var turboOn = false       // hold a modifier while scrolling → extra speed
    var turboFlag: CGEventFlags = .maskAlternate
    var turboSpeed: Double = 4

    var active: Bool { reversed || linear || speed != 1 || smooth || turboOn }

    /// Engine input from a profile's settings — the single mapping point between the two.
    init(_ settings: ScrollSettings) {
        self.init(reversed: settings.reversed, linear: settings.linear,
                  speed: settings.speed, smooth: settings.smooth,
                  turboOn: settings.turboOn, turboFlag: Self.flag(for: settings.turboKey),
                  turboSpeed: settings.turboSpeed)
    }

    init(reversed: Bool = false, linear: Bool = false, speed: Double = 1, smooth: Bool = false,
         turboOn: Bool = false, turboFlag: CGEventFlags = .maskAlternate, turboSpeed: Double = 4) {
        self.reversed = reversed
        self.linear = linear
        self.speed = speed
        self.smooth = smooth
        self.turboOn = turboOn
        self.turboFlag = turboFlag
        self.turboSpeed = turboSpeed
    }

    private static func flag(for key: TurboKey) -> CGEventFlags {
        switch key {
        case .option:  return .maskAlternate
        case .command: return .maskCommand
        case .control: return .maskControl
        }
    }
}

final class ScrollManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    // Per-app configs. Scrolling goes to the window under the CURSOR (macOS scrolls it without
    // activating the app), so the config is chosen by the app under the pointer, not frontmost.
    private var defaultConfig = ScrollConfig()
    private var appConfigs: [String: ScrollConfig] = [:]   // bundle id → config

    /// Apply the Default + per-app configs; starts or stops the tap as needed.
    /// Returns false if a transform is wanted but Accessibility is missing.
    @discardableResult
    func apply(default defaultConfig: ScrollConfig, perApp: [String: ScrollConfig]) -> Bool {
        self.defaultConfig = defaultConfig
        self.appConfigs = perApp
        if defaultConfig.active || perApp.values.contains(where: \.active) {
            return start()
        } else {
            stop()
            return true
        }
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard AccessibilityService.shared.trusted else { return false }

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
        // Accessibility revoked → an enabled active tap with no permission freezes all input.
        // Disable it now and tear it down off the callback (idempotent). Recreated on re-grant.
        if !AccessibilityService.shared.trusted {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return Unmanaged.passUnretained(event)
        }
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

        // The app under the cursor decides which profile's scroll settings apply.
        var config = configForCursor(at: event.location)
        guard config.active else { return Unmanaged.passUnretained(event) }

        // Turbo: boost while the chosen modifier is held — and strip the flag from the event so
        // the app underneath sees plain fast scrolling, never "⌥+scroll" (no zoom surprises).
        if config.turboOn, event.flags.contains(config.turboFlag) {
            config.speed *= config.turboSpeed
            event.flags.subtract(config.turboFlag)
        }

        transform(axis: (.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1), of: event, config: config)
        transform(axis: (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2), of: event, config: config)

        // Smooth: swallow the chunky step and glide the same distance over the next frames.
        if config.smooth { return smoothed(event, config: config) }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - App under the cursor

    private var cachedCursorPoint = CGPoint(x: -1_000_000, y: -1_000_000)
    private var cachedBundleID: String?

    /// Bundle id of the app owning the topmost normal window under the cursor. Cached until the
    /// cursor moves meaningfully — scroll streams fire hundreds of events at one position.
    private func configForCursor(at point: CGPoint) -> ScrollConfig {
        guard !appConfigs.isEmpty else { return defaultConfig }   // no per-app profiles → skip the lookup

        if hypot(point.x - cachedCursorPoint.x, point.y - cachedCursorPoint.y) > 8 {
            cachedCursorPoint = point
            cachedBundleID = WindowAtPoint.info(under: point)?.bundleID
        }
        guard let bundleID = cachedBundleID, let config = appConfigs[bundleID] else { return defaultConfig }
        return config
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
    private func smoothed(_ event: CGEvent, config: ScrollConfig) -> Unmanaged<CGEvent>? {
        let pointY = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let pointX = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        let lineY = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineX = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        pendingY += minimumStep(pointY != 0 ? pointY : lineY * 10, speed: config.speed)
        pendingX += minimumStep(pointX != 0 ? pointX : lineX * 10, speed: config.speed)
        pendingLinesY += lineY
        pendingLinesX += lineX

        if glideTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.glideTick() }
            RunLoop.main.add(timer, forMode: .common)
            glideTimer = timer
        }
        return nil
    }

    /// A slow tick reports ~10px — floor it so the glide is actually visible. The floor scales
    /// with the user's speed multiplier, otherwise it would flatten every speed below ~4×.
    private func minimumStep(_ delta: Double, speed: Double) -> Double {
        guard delta != 0 else { return 0 }
        let floor = 40 * speed
        return abs(delta) < floor ? (delta > 0 ? floor : -floor) : delta
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
    private func transform(axis: Axis, of event: CGEvent, config: ScrollConfig) {
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
