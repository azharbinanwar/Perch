//
//  HyperKeyManager.swift
//  Perch
//
//  Caps Lock as a Hyper key. Two layers:
//  1. hidutil remaps Caps Lock → F18 at the HID level (below event taps; also keeps the LED off).
//  2. Our tap gives F18 meaning: held + another key → that key gets ⌘⌥⌃(⇧) added; released
//     alone → the single/double-tap action (Escape / real Caps Lock toggle / nothing).
//
//  The hidutil mapping resets on reboot, so enable() re-applies it at every launch. Disabling
//  (or quitting) removes it so Caps Lock is never left dead. The tap is created once and gated
//  by `isEnabled` — never torn down (recreated taps don't reliably re-establish).
//

import AppKit
import CoreGraphics
import Foundation
import IOKit
import IOKit.hidsystem

final class HyperKeyManager {

    /// What a tap-alone does. rawValue doubles as the stored + displayed string.
    enum TapAction: String, CaseIterable, Identifiable {
        case escape = "Escape"
        case capsLock = "Caps Lock"
        case nothing = "Do Nothing"
        var id: String { rawValue }
    }

    var tapAction: TapAction = .escape
    var doubleTapAction: TapAction = .capsLock
    var includeShift = true

    /// Per-app gate: the hidutil remap stays installed (cheap, global) while the FRONTMOST
    /// app's profile decides behavior. Off → the key acts as a real Caps Lock again, so a
    /// terminal profile can keep Caps Lock while every other app gets Hyper.
    var perAppActive = true

    private(set) var isEnabled = false

    /// For the key recorder: is the hyper key physically held right now, and with which flags.
    var isHyperHeld: Bool { isEnabled && hyperDown }
    var activeFlags: CGEventFlags { hyperFlags }

    private let f18: Int64 = 79          // kVK_F18 — the dead key Caps Lock becomes
    private let escapeKey: CGKeyCode = 53
    private let doubleWindow: TimeInterval = 0.3

    private var hyperDown = false
    private var usedCombo = false        // a key was combined during this hold
    private var pendingTap: DispatchWorkItem?
    private var lastTapAt: TimeInterval = 0

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var hyperFlags: CGEventFlags {
        includeShift ? [.maskCommand, .maskAlternate, .maskControl, .maskShift]
                     : [.maskCommand, .maskAlternate, .maskControl]
    }

    // MARK: - Lifecycle

    func enable() {
        isEnabled = true
        setSystemRemap(true)
        startTap()
    }

    /// Turns the feature off and gives Caps Lock back. The tap stays alive, gated by `isEnabled`.
    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        hyperDown = false
        setSystemRemap(false)
    }

    /// Called on app quit — never leave Caps Lock remapped to a dead key.
    func cleanupForQuit() {
        if isEnabled { setSystemRemap(false) }
    }

    // MARK: - HID remap (Caps Lock → F18)

    private func setSystemRemap(_ on: Bool) {
        let mapping = on
            ? "[{\"HIDKeyboardModifierMappingSrc\":0x700000039,\"HIDKeyboardModifierMappingDst\":0x70000006D}]"
            : "[]"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        p.arguments = ["property", "--set", "{\"UserKeyMapping\":\(mapping)}"]
        try? p.run()
    }

    // MARK: - Tap

    private func startTap() {
        guard eventTap == nil, AccessibilityService.shared.trusted else { return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
                 | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<HyperKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    .handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Accessibility revoked → an enabled active tap with no permission freezes all input.
        // Disable it now, then off the callback undo the Caps remap and tear the tap down so a
        // later enable() rebuilds it.
        if !AccessibilityService.shared.trusted {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.disable()
                if let tap = self.eventTap {
                    CFMachPortInvalidate(tap)
                    if let source = self.runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
                    self.eventTap = nil
                    self.runLoopSource = nil
                }
            }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard isEnabled else { return Unmanaged.passUnretained(event) }

        // Never touch events Perch itself posts (action keystrokes like ⌘Space) — otherwise
        // holding Caps while an action fires would stamp hyper flags onto our own output.
        if event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(ProcessInfo.processInfo.processIdentifier) {
            return Unmanaged.passUnretained(event)
        }

        let code = event.getIntegerValueField(.keyboardEventKeycode)

        if code == f18 {
            // Profile says Hyper is off for the frontmost app → emulate the real key: the HID
            // remap is still in place, so we toggle actual Caps Lock (and its LED) ourselves.
            if !perAppActive {
                if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    toggleRealCapsLock()
                }
                hyperDown = false
                return nil
            }
            switch type {
            case .keyDown:
                if !hyperDown { hyperDown = true; usedCombo = false }
                return nil                        // swallow (incl. autorepeat)
            case .keyUp:
                hyperDown = false
                if !usedCombo { handleTapAlone() }
                return nil
            default:
                return Unmanaged.passUnretained(event)
            }
        }

        // Any other key while Hyper is held → same key with the hyper modifiers added.
        if hyperDown {
            usedCombo = true
            event.flags = event.flags.union(hyperFlags)
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Tap-alone (single / double)

    private func handleTapAlone() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTapAt < doubleWindow {
            pendingTap?.cancel(); pendingTap = nil
            lastTapAt = 0
            perform(doubleTapAction)
        } else {
            lastTapAt = now
            if doubleTapAction == .nothing {
                perform(tapAction)               // no double configured → fire instantly
            } else {
                let action = tapAction
                let work = DispatchWorkItem { [weak self] in
                    self?.pendingTap = nil
                    self?.perform(action)
                }
                pendingTap = work
                DispatchQueue.main.asyncAfter(deadline: .now() + doubleWindow, execute: work)
            }
        }
    }

    private func perform(_ action: TapAction) {
        switch action {
        case .escape:
            let source = CGEventSource(stateID: .combinedSessionState)
            CGEvent(keyboardEventSource: source, virtualKey: escapeKey, keyDown: true)?.post(tap: .cgSessionEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: escapeKey, keyDown: false)?.post(tap: .cgSessionEventTap)
        case .capsLock:
            toggleRealCapsLock()
        case .nothing:
            break
        }
    }

    /// Toggle the actual caps-lock state (and its LED) via IOKit — the HID remap means the key
    /// itself can no longer do it.
    private func toggleRealCapsLock() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connect) }
        var state = false
        IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
        IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), !state)
    }
}
