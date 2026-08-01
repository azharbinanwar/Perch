//
//  RemapManager.swift
//  Perch
//
//  Manager. CGEventTap on key events. When a key + its modifiers match a rule's input, do the
//  rule's Action: a custom keystroke rewrites the event in place (so hold/repeat/keyUp still
//  pair up); any other action swallows the key and runs it. Requires Accessibility permission.
//
//  ponytail: applies to ALL keyboards. A CGEventTap has no device ID, so external-only would
//  need a virtual-HID driver (Karabiner-style). Per-app profiles cover the practical cases.
//

import AppKit
import CoreGraphics

final class RemapManager {
    /// Current rules, pushed in by the ViewModel.
    var rules: [RemapRule] = []

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var translated: [Int: KeyCombo] = [:]   // keycode → rewritten combo, so keyUp mirrors keyDown
    private var swallowed: Set<Int> = []            // keycodes whose keyDown we ate for an action

    // Smart detect: a hardware shortcut key sends modifier+key as one burst (measured ≤5.4ms);
    // human rolls are ≥17.5ms. Below the threshold = machine → remap; above = typed → pass
    // through (⌃C in Terminal stays an interrupt). Timestamps come from the events themselves,
    // never arrival time (a busy main thread would stretch the gap and misclassify).
    static let smartThresholdMs = 10.0
    private let selfPID = Int64(ProcessInfo.processInfo.processIdentifier)
    private var prevFlags = CGEventFlags()
    private var modDownTS: UInt64 = 0            // when the last significant modifier went down
    private var smartHumanHeld: Set<Int> = []    // keycodes judged "typed" — latched until keyUp

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard AccessibilityService.shared.trusted else { return false }

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue))   // smart detect: time the modifier press
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,   // always AFTER the hyper/recorder taps — so a hyper'd
                                          // key arrives here with its ⌘⌥⌃⇧ flags already added
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<RemapManager>.fromOpaque(refcon).takeUnretainedValue()
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

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    /// The Keys module's master switch, pushed by the ViewModel — the engine's cheap hot-path gate.
    var keysModuleEnabled = false

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables the tap on timeout/revoke; re-enable + pass. Never call Accessibility here.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if !keysModuleEnabled { return Unmanaged.passUnretained(event) }   // 1) master toggle
        if !AccessibilityService.shared.isTrusted {                        // 2) cached permission
            NSLog("[Perch:Acc] remap: cached permission off → markAllOff")
            AccessibilityService.shared.markAllOff()
            return Unmanaged.passUnretained(event)
        }

        // Our own synthesized keystrokes (actions, paste) pass through untouched — they'd
        // read as sub-ms hardware bursts and could be re-remapped by our own rules.
        if event.getIntegerValueField(.eventSourceUnixProcessID) == selfPID {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Remember when a significant modifier physically went down (any of ⌃⌥⇧⌘).
        if type == .flagsChanged {
            let now = event.flags.intersection(KeyCombo.significant)
            if !now.subtracting(prevFlags).isEmpty { modDownTS = event.timestamp }
            prevFlags = now
            return Unmanaged.passUnretained(event)
        }
        // keyUp: mirror whatever we did to the keyDown so the app sees a matching pair.
        if type == .keyUp {
            smartHumanHeld.remove(keyCode)
            if let output = translated.removeValue(forKey: keyCode) { rewrite(event, to: output) }
            else if swallowed.remove(keyCode) != nil { return nil }   // swallow the up of an eaten key
            return Unmanaged.passUnretained(event)
        }

        // keyDown
        let mods = event.flags.intersection(KeyCombo.significant).rawValue
        guard let rule = rules.first(where: {
            $0.isEnabled && $0.input.keyCode == keyCode && $0.input.modifiers == mods
        }) else {
            return Unmanaged.passUnretained(event)
        }

        // Smart detect: modified rules fire only for hardware bursts. The verdict is decided
        // on the FIRST press and latched until keyUp — auto-repeats carry a stale modifier
        // timestamp and would otherwise flip to "human" mid-hold.
        if rule.smartDetect, rule.input.hasModifiers {
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                if smartHumanHeld.contains(keyCode) { return Unmanaged.passUnretained(event) }
            } else {
                let ms = Double(event.timestamp &- modDownTS) / 1_000_000
                if modDownTS == 0 || ms >= Self.smartThresholdMs {
                    smartHumanHeld.insert(keyCode)
                    return Unmanaged.passUnretained(event)   // typed by hand → native meaning
                }
            }
        }

        let action = rule.output
        if action.kind == .passThrough { return Unmanaged.passUnretained(event) }

        // Custom keystroke → rewrite the event in place (keeps hold/repeat/keyUp behaviour).
        if action.kind == .customKeystroke, let code = action.keyCode {
            let combo = KeyCombo(keyCode: code, modifiers: action.modifiers ?? 0)
            translated[keyCode] = combo
            rewrite(event, to: combo)
            return Unmanaged.passUnretained(event)
        }

        // Any other action → swallow the key and run it (once, not on auto-repeat).
        swallowed.insert(keyCode)
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { ActionRunner.run(action) }
        return nil
    }

    /// Rewrite an event to an output combo: swap keycode and the significant modifier flags.
    private func rewrite(_ event: CGEvent, to output: KeyCombo) {
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(output.keyCode))
        var newFlags = event.flags
        newFlags.remove(KeyCombo.significant)
        newFlags.insert(CGEventFlags(rawValue: output.modifiers))
        event.flags = newFlags
    }
}
