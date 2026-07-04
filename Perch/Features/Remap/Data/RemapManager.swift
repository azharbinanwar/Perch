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

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard Permissions.isAccessibilityTrusted else { return false }

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
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

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // keyUp: mirror whatever we did to the keyDown so the app sees a matching pair.
        if type == .keyUp {
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
