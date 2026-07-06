//
//  DoubleTapManager.swift
//  Perch
//
//  Double-tap a modifier (⇧⌘⌥⌃) alone → run an action. Modifiers arrive as flagsChanged
//  events, not key presses, so this has its own small listen-only tap (it never swallows
//  anything — typing can't break). A "tap" counts only when the modifier goes down and up
//  with no other key or modifier involved; two taps inside the window fire the action.
//

import AppKit
import CoreGraphics
import Foundation

struct DoubleTapConfig: Codable, Equatable {
    var enabled = false
    var actions: [String: Action] = [:]   // keys: "shift" / "command" / "option" / "control"
    static let `default` = DoubleTapConfig()
}

final class DoubleTapManager {

    static let modifiers: [(key: String, symbol: String, name: String, flag: CGEventFlags)] = [
        ("shift",   "⇧", "Shift",   .maskShift),
        ("command", "⌘", "Command", .maskCommand),
        ("option",  "⌥", "Option",  .maskAlternate),
        ("control", "⌃", "Control", .maskControl),
    ]

    var config = DoubleTapConfig()
    var isActive = false          // master switch && section toggle — set by the ViewModel

    private let window: TimeInterval = 0.35
    private let significant: CGEventFlags = [.maskShift, .maskCommand, .maskAlternate, .maskControl]

    private var lastFlags: CGEventFlags = []
    private var candidate: String?        // modifier currently held alone (tap in progress)
    private var dirty = false             // another key/modifier joined — not a tap
    private var lastTapAt: [String: TimeInterval] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Create the tap once; `isActive` gates behavior (never torn down).
    func start() {
        guard eventTap == nil, AccessibilityService.shared.trusted else { return }
        let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
                 | (CGEventMask(1) << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                Unmanaged<DoubleTapManager>.fromOpaque(refcon).takeUnretainedValue()
                    .handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard isActive else { return }

        // Any real key press breaks the tap sequence (⇧A ⇧A must never fire).
        if type == .keyDown {
            dirty = true
            lastTapAt.removeAll()
            return
        }

        guard type == .flagsChanged else { return }
        let now = event.flags.intersection(significant)
        defer { lastFlags = now }

        for mod in Self.modifiers {
            let was = lastFlags.contains(mod.flag)
            let is_ = now.contains(mod.flag)

            if !was && is_ {                                    // modifier went DOWN
                if now == mod.flag && candidate == nil {
                    candidate = mod.key                          // held alone — a tap may be starting
                    dirty = false
                } else {
                    dirty = true                                 // combined with something else
                }
            } else if was && !is_ {                              // modifier went UP
                if candidate == mod.key && !dirty {
                    tapCompleted(mod.key)
                }
                if candidate == mod.key { candidate = nil }
            }
        }
    }

    private func tapCompleted(_ key: String) {
        let now = ProcessInfo.processInfo.systemUptime
        if now - (lastTapAt[key] ?? 0) < window {
            lastTapAt[key] = 0
            if let action = config.actions[key] {
                DispatchQueue.main.async { ActionRunner.run(action) }
            }
        } else {
            lastTapAt[key] = now
        }
    }
}
