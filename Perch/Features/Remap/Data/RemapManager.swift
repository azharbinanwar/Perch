//
//  RemapManager.swift
//  Perch
//
//  Manager. CGEventTap on key events. When Ctrl (and only Ctrl) + a mapped key is
//  pressed and the frontmost app isn't excluded, swap Ctrl → Cmd.
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

    // Virtual keycodes for the letters we support.
    private static let keyCodeForChar: [Int64: String] = [
        0: "a", 6: "z", 7: "x", 8: "c", 9: "v", 35: "p", 37: "l"
    ]

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
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    var isRunning: Bool { eventTap != nil }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        // Only act on Ctrl-and-not-Cmd, so we never touch existing Cmd shortcuts.
        guard flags.contains(.maskControl), !flags.contains(.maskCommand) else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let char = RemapManager.keyCodeForChar[keyCode],
              let rule = rules.first(where: { $0.isEnabled && $0.keyChar == char }),
              !isExcludedAppFrontmost(rule) else {
            return Unmanaged.passUnretained(event)
        }

        var newFlags = flags
        newFlags.remove(.maskControl)
        newFlags.insert(.maskCommand)
        event.flags = newFlags
        return Unmanaged.passUnretained(event)
    }

    private func isExcludedAppFrontmost(_ rule: RemapRule) -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return rule.excludedBundleIDs.contains(bundleID)
    }
}
