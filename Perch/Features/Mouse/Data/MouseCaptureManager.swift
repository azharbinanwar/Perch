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

    /// Swap primary/secondary buttons (left-handed). Set by the ViewModel; read per event.
    var swapEnabled = false

    // Mouse Shift: while `layerHoldButton` is physically held, other buttons run their layer
    // mapping instead. HOLDING is the shift gesture — but a tap alone (no combo) still fires
    // the shift key's own click/double actions, or passes a raw click through if it has none.
    private var layerHoldButtons: Set<Int> = []     // ANY of these engages the shift while held
    private var layerHeldButton: Int?               // which one is physically down right now
    private var layerActiveHold: Int?               // whose combo set is in force (survives release for grace)
    private var layerMappings: [Int: [Int: MouseMapping]] = [:]   // hold key → target button → combo
    private var layerHeld = false
    private var layerUsedCombo = false              // another button was pressed during this hold
    private var layerTapAt: TimeInterval = 0        // for the shift key's own double-click
    private var layerPendingSingle: DispatchWorkItem?

    // Grace: some mice queue a click behind the hold's release (it lands the same instant the
    // hold lifts), and humans release a hair early. A click shortly AFTER the release still
    // counts as a shift combo; the tap-alone fires only after the grace passes untouched.
    private let layerGrace: TimeInterval = 0.25
    private var layerGraceUntil: TimeInterval = 0
    private var layerGraceWork: DispatchWorkItem?

    private var layerGraceActive: Bool {
        ProcessInfo.processInfo.systemUptime < layerGraceUntil
    }

    private func consumeLayerGrace() {
        layerGraceWork?.cancel()
        layerGraceWork = nil
        layerGraceUntil = 0
    }
    private var activePressMapping: MouseMapping?   // mapping captured at press time — the layer
                                                    // key may be released before the target's up
    private let selfPID = Int64(ProcessInfo.processInfo.processIdentifier)

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

    func apply(mappings: [MouseMapping], gestures gestureList: [MouseGesture],
               layers: [Int: [MouseMapping]] = [:]) {
        buttonMappings = [:]
        keyClicks = [:]
        for mapping in mappings where mapping.action.kind != .passThrough || mapping.hasVariants {
            switch mapping.trigger {
            case .button(let n): buttonMappings[n] = mapping
            case .key:           keyClicks[mapping.trigger] = mapping.action
            }
        }
        gestures = Dictionary(gestureList.map { ($0.button, $0) }, uniquingKeysWith: { _, last in last })

        layerHoldButtons = Set(layers.keys)
        layerMappings = [:]
        for (hold, list) in layers {
            var byTarget: [Int: MouseMapping] = [:]
            for mapping in list {
                if case .button(let n) = mapping.trigger { byTarget[n] = mapping }
            }
            layerMappings[hold] = byTarget
        }
        if layers.isEmpty { layerHeld = false; layerHeldButton = nil; layerActiveHold = nil }
        // Dump the exact stored config — settles "what is actually set" without guessing.
        if !layers.isEmpty {
            func s(_ a: Action) -> String { a.kind == .disabled ? "—" : a.displayLabel }
            let dump = layerMappings.keys.sorted().map { hold -> String in
                let combos = layerMappings[hold]!.keys.sorted().map { n -> String in
                    let m = layerMappings[hold]![n]!
                    return "\(MouseButton.name(for: n)): click=\(s(m.action)), double=\(s(m.doubleAction)), hold=\(s(m.holdAction))"
                }.joined(separator: ", ")
                return "hold \(MouseButton.name(for: hold)) → [\(combos)]"
            }.joined(separator: " | ")
            DiagLog.shared.append("🔧 SHIFT CONFIG — \(dump)")
        }
        // Dictionaries only; the live tap reads them on the next event. Tap lifecycle is start()/stop(),
        // driven by the ViewModel's enabled state — so editing mappings never recreates the tap.
    }

    // MARK: - Tap

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil, AccessibilityService.shared.trusted else { return false }
        // Always include keyDown so adding a keystroke-button never needs a tap recreate.
        // Left/right drags are tapped for the swap feature — without them a swapped drag
        // would report the un-swapped button mid-drag.
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
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
        // Accessibility revoked → an enabled active tap with no permission freezes all input.
        // Disable it now and tear it down off the callback (idempotent). Recreated on re-grant.
        if !AccessibilityService.shared.trusted {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Left-handed swap — rewrite the event in place and pass it on. Runs before the
        // Perch-frontmost guard so the buttons feel the same inside Perch too.
        if swapEnabled {
            switch type {
            case .leftMouseDown:     return swapped(event, to: .rightMouseDown, button: 1)
            case .leftMouseUp:       return swapped(event, to: .rightMouseUp, button: 1)
            case .leftMouseDragged:  return swapped(event, to: .rightMouseDragged, button: 1)
            case .rightMouseDown:    return swapped(event, to: .leftMouseDown, button: 0)
            case .rightMouseUp:      return swapped(event, to: .leftMouseUp, button: 0)
            case .rightMouseDragged: return swapped(event, to: .leftMouseDragged, button: 0)
            default: break
            }
        }

        // Our own synthesized events (tap-alone click replay) pass through untouched.
        if event.getIntegerValueField(.eventSourceUnixProcessID) == selfPID {
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
            let button = buttonID(type, event)
            // A shift key: engage ITS combo set. Its own hold action never runs (holding IS the
            // shift gesture); click/double are decided on release, by whether a combo happened.
            // While a layer is already engaged, a second shift key acts as a normal target —
            // so shift-key + shift-key combos work too.
            if !layerHeld, layerHoldButtons.contains(button) {
                consumeLayerGrace()   // a re-press cancels any pending tap-alone
                layerHeld = true
                layerHeldButton = button
                layerActiveHold = button
                layerUsedCombo = false
                DiagLog.shared.append("🟠 \(MouseButton.name(for: button)) DOWN — SHIFT KEY engaged")
                return nil
            }
            let shiftNow = layerHeld || layerGraceActive
            var note = ""
            if shiftNow {
                if let m = layerMapping(button) {
                    func s(_ a: Action) -> String { a.kind == .disabled ? "—" : a.displayLabel }
                    note = " — under shift → click=\(s(m.action)), double=\(s(m.doubleAction)), hold=\(s(m.holdAction))\(layerGraceActive && !layerHeld ? " (grace)" : "")"
                } else {
                    note = " — under shift → NO layer mapping for this button"
                }
            }
            DiagLog.shared.append("⬇️ \(MouseButton.name(for: button)) DOWN\(note)")
            if shiftNow {
                layerUsedCombo = true                          // any button during the hold = a combo
                if !layerHeld { consumeLayerGrace() }          // the queued/late click IS the combo
            }
            return handleDown(button: button, event: event, shift: shiftNow)
        case .otherMouseDragged:
            return handleDrag(button: buttonID(type, event), event: event)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            let button = buttonID(type, event)
            DiagLog.shared.append("⬆️ \(MouseButton.name(for: button)) UP")
            if layerHoldButtons.contains(button), button == layerHeldButton {
                layerHeld = false
                layerHeldButton = nil
                DiagLog.shared.append("🟠 SHIFT KEY released (combo used: \(layerUsedCombo))")
                if !layerUsedCombo {
                    // Tap? Not so fast — give the grace window a chance to reveal a late combo
                    // click (queued by the mouse, or a slightly-early release).
                    layerGraceUntil = ProcessInfo.processInfo.systemUptime + layerGrace
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        self.layerGraceWork = nil
                        self.layerGraceUntil = 0
                        self.layerTapAlone(button)
                    }
                    layerGraceWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + layerGrace, execute: work)
                }
                return nil
            }
            return handleUp(button: button, event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Shift key tap-alone (its click/double survive; hold is the shift gesture)

    /// The combo for a target button under the CURRENTLY engaged shift key (grace included).
    private func layerMapping(_ button: Int) -> MouseMapping? {
        layerActiveHold.flatMap { layerMappings[$0]?[button] }
    }

    private func layerTapAlone(_ button: Int) {
        let mapping = buttonMappings[button]
        let single = mapping?.action
        let double = mapping?.doubleAction

        let now = ProcessInfo.processInfo.systemUptime
        if let double, double.kind != .disabled {
            if now - layerTapAt < doubleWindow {
                layerPendingSingle?.cancel(); layerPendingSingle = nil
                layerTapAt = 0
                run(double)
            } else {
                layerTapAt = now
                let work = DispatchWorkItem { [weak self] in
                    self?.layerPendingSingle = nil
                    self?.fireLayerSingle(single, button: button)
                }
                layerPendingSingle = work
                DispatchQueue.main.asyncAfter(deadline: .now() + doubleWindow, execute: work)
            }
        } else {
            fireLayerSingle(single, button: button)
        }
    }

    /// The tap's click: the mapped action if there is one, else replay the raw click so the
    /// button's native behavior (middle-click paste, open-in-tab…) still works.
    private func fireLayerSingle(_ single: Action?, button: Int) {
        if let single, single.kind != .disabled, single.kind != .passThrough {
            run(single)
        } else {
            synthesizeClick(button)
        }
    }

    /// Replay a real press of this button at the cursor — our own tap ignores it (PID guard).
    private func synthesizeClick(_ button: Int) {
        let position = CGEvent(source: nil)?.location ?? .zero
        let source = CGEventSource(stateID: .combinedSessionState)
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            let event = CGEvent(mouseEventSource: source, mouseType: type,
                                mouseCursorPosition: position, mouseButton: .center)
            event?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
            event?.post(tap: .cgSessionEventTap)
        }
    }

    private func handleDown(button: Int, event: CGEvent, shift: Bool = false) -> Unmanaged<CGEvent>? {
        let mapping = shift ? layerMapping(button) : buttonMappings[button]
        let gesture = shift ? nil : gestures[button]   // gestures stay normal-layer only
        guard mapping != nil || gesture != nil else { return Unmanaged.passUnretained(event) }
        activePressMapping = mapping   // freeze — the layer key may lift before this press ends

        // Second click inside the double window → double action.
        if let pending = pendingSingle[button],
           ProcessInfo.processInfo.systemUptime - (lastUp[button] ?? 0) < doubleWindow {
            pending.cancel(); pendingSingle[button] = nil
            activeButton = button; dx = 0; dy = 0; consumed = true
            if let action = mapping?.doubleAction, action.kind != .disabled {
                DiagLog.shared.append("✨ DOUBLE-CLICK action → \(action.displayLabel)")
                run(action)
            }
            return nil
        }

        activeButton = button; dx = 0; dy = 0; consumed = false
        if let hold = mapping?.holdAction, hold.kind != .disabled {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.activeButton == button, !self.consumed else { return }
                self.consumed = true
                DiagLog.shared.append("✨ HOLD action → \(hold.displayLabel)")
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
            if !layerHeld, let gesture = gestures[button] {
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

        let mapping = activePressMapping        // the set that was in force when the press began
        let single = mapping?.action
        if mapping?.doubleAction.kind != .disabled {
            // Wait for a possible second click before committing the single.
            lastUp[button] = ProcessInfo.processInfo.systemUptime
            let work = DispatchWorkItem { [weak self] in
                self?.pendingSingle[button] = nil
                if let single, single.kind != .disabled {
                    DiagLog.shared.append("✨ CLICK action → \(single.displayLabel)")
                    self?.run(single)
                }
            }
            pendingSingle[button] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleWindow, execute: work)
        } else if let single, single.kind != .disabled {
            DiagLog.shared.append("✨ CLICK action → \(single.displayLabel)")
            run(single)
        }
        return nil
    }

    // MARK: - Helpers

    /// Rewrite a left/right event as its opposite (type + button number) and pass it through.
    private func swapped(_ event: CGEvent, to type: CGEventType, button: Int64) -> Unmanaged<CGEvent>? {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: button)
        return Unmanaged.passUnretained(event)
    }

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
