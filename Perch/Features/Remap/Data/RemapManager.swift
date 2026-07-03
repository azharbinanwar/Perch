//
//  RemapManager.swift
//  Perch
//
//  Manager. CGEventTap on key events. When a key + its modifiers match a rule's input combo
//  and the frontmost app isn't excluded, rewrite the event to the output combo (keycode + flags).
//  Requires Accessibility permission.
//
//  ponytail: applies to ALL keyboards. Filtering to external-only isn't possible from a
//  CGEventTap (no device ID on the event) — that needs a virtual-HID driver (Karabiner-style).
//  Per-app exclusion (Terminal) covers the practical harm; add a driver only if built-in must be spared.
//

import AppKit
import CoreGraphics

final class RemapManager {
    /// Current rules, pushed in by the ViewModel.
    var rules: [RemapRule] = []

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

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

    var isRunning: Bool { eventTap != nil }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let mods = event.flags.intersection(KeyCombo.significant).rawValue

        guard let rule = rules.first(where: {
            $0.isEnabled && $0.input.keyCode == keyCode && $0.input.modifiers == mods
        }), !isExcludedAppFrontmost(rule) else {
            return Unmanaged.passUnretained(event)
        }

        // Rewrite to the output combo: swap keycode and the significant modifier flags.
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(rule.output.keyCode))
        var newFlags = event.flags
        newFlags.remove(KeyCombo.significant)
        newFlags.insert(CGEventFlags(rawValue: rule.output.modifiers))
        event.flags = newFlags
        return Unmanaged.passUnretained(event)
    }

    private func isExcludedAppFrontmost(_ rule: RemapRule) -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return rule.excludedBundleIDs.contains(bundleID)
    }
}
