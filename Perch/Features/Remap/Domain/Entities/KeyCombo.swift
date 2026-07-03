//
//  KeyCombo.swift
//  Perch
//
//  A key + its significant modifiers (⌃⌥⇧⌘). Both sides of a remap rule are KeyCombos.
//

import CoreGraphics
import Foundation

struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: Int
    var modifiers: UInt64          // CGEventFlags raw of the four significant modifiers

    var displayName: String { MouseTrigger.modifierSymbols(modifiers) + KeyCombo.keyName(keyCode) }

    /// The modifier bits we care about — everything else (caps lock, fn, numeric) is ignored.
    static let significant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

    static func keyName(_ code: Int) -> String {
        if let name = names[code] { return name }
        return "Key \(code)"
    }

    // Virtual keycodes → readable labels (US ANSI layout; enough for a remapper).
    private static let names: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
}
