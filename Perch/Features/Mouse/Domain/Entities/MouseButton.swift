//
//  MouseButton.swift
//  Perch
//
//  A physical mouse button, identified by its macOS button number
//  (0 = left, 1 = right, 2 = middle, 3+ = extra buttons).
//

import Foundation

enum MouseButton {
    /// Human name for a button number.
    static func name(for number: Int) -> String {
        switch number {
        case 0: return "Left"
        case 1: return "Right"
        case 2: return "Middle"
        default: return "Button \(number + 1)"
        }
    }

    /// SF Symbol for a button number.
    static func icon(for number: Int) -> String {
        switch number {
        case 0, 1, 2: return "computermouse"
        default:      return "computermouse.fill"
        }
    }
}
