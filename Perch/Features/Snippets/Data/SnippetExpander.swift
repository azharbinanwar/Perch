//
//  SnippetExpander.swift
//  Perch
//
//  Text expansion: watches typing (listen-only — can never break input), keeps a small rolling
//  buffer of what was typed, and when it ends with prefix+abbreviation (e.g. ";addr") deletes
//  those characters and types the snippet text in their place. No clipboard involved.
//

import AppKit
import CoreGraphics
import Foundation

/// The character(s) every abbreviation starts with. rawValue is both the stored and shown string.
enum ExpansionPrefix: String, CaseIterable, Identifiable {
    case semicolon = ";"
    case colon = ":"
    case doubleSlash = "//"
    var id: String { rawValue }
    static let `default`: ExpansionPrefix = .semicolon
}

final class SnippetExpander {

    var isActive = false
    var prefix = ExpansionPrefix.default.rawValue
    var abbreviations: [String: String] = [:]   // abbreviation (no prefix) → full text

    private var buffer = ""
    private let maxBuffer = 40
    private let backspace: CGKeyCode = 51

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Create the tap once; `isActive` gates behavior (never torn down).
    func start() {
        guard eventTap == nil, Permissions.isAccessibilityTrusted else { return }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                Unmanaged<SnippetExpander>.fromOpaque(refcon).takeUnretainedValue()
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
        guard isActive, !abbreviations.isEmpty, type == .keyDown else { return }

        // Ignore our own synthesized events (the backspaces + typed replacement).
        if event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(ProcessInfo.processInfo.processIdentifier) {
            return
        }

        // Shortcuts (⌘⌥⌃ involved) aren't typing — reset the sequence.
        if !event.flags.intersection([.maskCommand, .maskAlternate, .maskControl]).isEmpty {
            buffer = ""
            return
        }

        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if code == Int64(backspace) {
            if !buffer.isEmpty { buffer.removeLast() }
            return
        }

        // What character did this key type?
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0, let scalar = Unicode.Scalar(chars[0]) else { buffer = ""; return }

        // Control keys (return, tab, esc, arrows F700+) break the sequence.
        if scalar.value < 0x20 || (0xF700...0xF8FF).contains(scalar.value) {
            buffer = ""
            return
        }

        buffer.append(Character(scalar))
        if buffer.count > maxBuffer { buffer.removeFirst(buffer.count - maxBuffer) }

        for (abbreviation, text) in abbreviations {
            let token = prefix + abbreviation
            if buffer.hasSuffix(token) {
                buffer = ""
                // Tiny delay so the app finishes receiving the last typed character first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                    self?.replace(count: token.count, with: text)
                }
                break
            }
        }
    }

    /// Delete the typed token, then type the snippet text (chunked unicode events — no clipboard).
    private func replace(count: Int, with text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<count {
            CGEvent(keyboardEventSource: source, virtualKey: backspace, keyDown: true)?.post(tap: .cgSessionEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: backspace, keyDown: false)?.post(tap: .cgSessionEventTap)
        }
        var remaining = Substring(text)
        while !remaining.isEmpty {
            let chunk = remaining.prefix(20)
            remaining = remaining.dropFirst(chunk.count)
            let utf16 = Array(String(chunk).utf16)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down?.post(tap: .cgSessionEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)?.post(tap: .cgSessionEventTap)
        }
    }
}
