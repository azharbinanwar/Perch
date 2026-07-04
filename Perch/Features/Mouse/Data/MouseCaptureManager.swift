//
//  MouseCaptureManager.swift
//  Perch
//
//  The live button engine. Per button it disambiguates single / double / hold clicks and
//  hold-and-move gestures, firing the matching action. Key-chord buttons fire a single action.
//  Never applies while Perch itself is frontmost. Requires Accessibility.
//
//  Timing: a button with no double/hold configured fires its single action on release (no
//  delay to notice). If double is configured, the single waits one double-click window so a
//  second click can upgrade it; if hold is configured, holding past the hold delay fires it.
//

import AppKit
import CoreGraphics
import Foundation

final class MouseCaptureManager {
    private var buttonMappings: [Int: MouseMapping] = [:]
    private var keyClicks: [MouseTrigger: Action] = [:]
    private var gestures: [Int: MouseGesture] = [:]

    private let moveThreshold: CGFloat = 30
    private let holdDelay: TimeInterval = 0.30
    private let doubleWindow: TimeInterval = 0.25

    // Current press.
    private var activeButton: Int?
    private var dx: CGFloat = 0
    private var dy: CGFloat = 0
    private var consumed = false          // gesture / hold / double already handled this press
    private var holdWork: DispatchWorkItem?

    // Between presses (for double detection).
    private var pendingSingle: [Int: DispatchWorkItem] = [:]
    private var lastUp: [Int: TimeInterval] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func apply(mappings: [MouseMapping], gestures gestureList: [MouseGesture]) {
        buttonMappings = [:]
        keyClicks = [:]
        for mapping in mappings where mapping.action.kind != .passThrough || mapping.hasVariants {
            switch mapping.trigger {
            case .button(let n): buttonMappings[n] = mapping
            case .key:           keyClicks[mapping.trigger] = mapping.action
            }
        }
        gestures = Dictionary(gestureList.map { ($0.button, $0) }, uniquingKeysWith: { _, last in last })
        // Dictionaries only; the live tap reads them on the next event. Tap lifecycle is start()/stop(),
        // driven by the ViewModel's enabled state — so editing mappings never recreates the tap.
    }

    // MARK: - Tap

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil, Permissions.isAccessibilityTrusted else { return false }
        // Always include keyDown so adding a keystroke-button never needs a tap recreate.
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged, .keyDown,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MouseCaptureManager>.fromOpaque(refcon).takeUnretainedValue()
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
        activeButton = nil
        holdWork?.cancel(); holdWork = nil
        pendingSingle.values.forEach { $0.cancel() }
        pendingSingle = [:]
    }

    // MARK: - Handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let mods = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).rawValue
            if let action = keyClicks[.key(code: code, modifiers: mods)] { run(action); return nil }
            return Unmanaged.passUnretained(event)

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return handleDown(button: buttonID(type, event), event: event)
        case .otherMouseDragged:
            return handleDrag(button: buttonID(type, event), event: event)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return handleUp(button: buttonID(type, event), event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleDown(button: Int, event: CGEvent) -> Unmanaged<CGEvent>? {
        let mapping = buttonMappings[button]
        guard mapping != nil || gestures[button] != nil else { return Unmanaged.passUnretained(event) }

        // Second click inside the double window → double action.
        if let pending = pendingSingle[button],
           ProcessInfo.processInfo.systemUptime - (lastUp[button] ?? 0) < doubleWindow {
            pending.cancel(); pendingSingle[button] = nil
            activeButton = button; dx = 0; dy = 0; consumed = true
            if let action = mapping?.doubleAction, action.kind != .disabled { run(action) }
            return nil
        }

        activeButton = button; dx = 0; dy = 0; consumed = false
        if let hold = mapping?.holdAction, hold.kind != .disabled {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.activeButton == button, !self.consumed else { return }
                self.consumed = true
                self.run(hold)
            }
            holdWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: work)
        }
        return nil
    }

    private func handleDrag(button: Int, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let active = activeButton, active == button else { return Unmanaged.passUnretained(event) }
        dx += CGFloat(event.getIntegerValueField(.mouseEventDeltaX))
        dy += CGFloat(event.getIntegerValueField(.mouseEventDeltaY))
        if !consumed, hypot(dx, dy) >= moveThreshold {
            holdWork?.cancel()
            consumed = true
            if let gesture = gestures[button] {
                let action = gesture.action(for: direction(dx: dx, dy: dy))
                if action.kind != .disabled { run(action) }
            }
        }
        return nil
    }

    private func handleUp(button: Int, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let active = activeButton, active == button else { return Unmanaged.passUnretained(event) }
        activeButton = nil
        holdWork?.cancel(); holdWork = nil
        if consumed { return nil }              // gesture / hold / double already fired

        let mapping = buttonMappings[button]
        let single = mapping?.action
        if mapping?.doubleAction.kind != .disabled {
            // Wait for a possible second click before committing the single.
            lastUp[button] = ProcessInfo.processInfo.systemUptime
            let work = DispatchWorkItem { [weak self] in
                self?.pendingSingle[button] = nil
                if let single, single.kind != .disabled { self?.run(single) }
            }
            pendingSingle[button] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleWindow, execute: work)
        } else if let single, single.kind != .disabled {
            run(single)
        }
        return nil
    }

    // MARK: - Helpers

    private func buttonID(_ type: CGEventType, _ event: CGEvent) -> Int {
        switch type {
        case .leftMouseDown, .leftMouseUp:   return 0
        case .rightMouseDown, .rightMouseUp: return 1
        default:                             return Int(event.getIntegerValueField(.mouseEventButtonNumber))
        }
    }

    private func direction(dx: CGFloat, dy: CGFloat) -> GestureDirection {
        if abs(dx) >= abs(dy) { return dx >= 0 ? .right : .left }
        return dy >= 0 ? .down : .up
    }

    private func run(_ action: Action) {
        DispatchQueue.main.async { ActionRunner.run(action) }
    }
}
