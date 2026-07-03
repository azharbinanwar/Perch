//
//  MouseTrigger.swift
//  Perch
//
//  What fires a mapping: a physical mouse button, or a key chord (some buttons emit a
//  keystroke instead of a button event).
//

import CoreGraphics

enum MouseTrigger: Codable, Equatable, Hashable {
    case button(Int)                       // macOS button number
    case key(code: Int, modifiers: UInt64) // CGEventFlags rawValue

    var displayName: String {
        switch self {
        case .button(let n):
            return MouseButton.name(for: n)
        case .key(let code, let modifiers):
            return Self.modifierSymbols(modifiers) + "key\(code)"
        }
    }

    static func modifierSymbols(_ modifiers: UInt64) -> String {
        let flags = CGEventFlags(rawValue: modifiers)
        var s = ""
        if flags.contains(.maskControl)   { s += "⌃" }
        if flags.contains(.maskAlternate) { s += "⌥" }
        if flags.contains(.maskShift)     { s += "⇧" }
        if flags.contains(.maskCommand)   { s += "⌘" }
        return s
    }
}
