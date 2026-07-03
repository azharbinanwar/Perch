//
//  Permissions.swift
//  Perch
//
//  Accessibility permission gate for the CGEventTap features (Scroll, Remap).
//

import ApplicationServices
import AppKit

enum Permissions {
    /// True if the app is trusted for Accessibility (required to run event taps).
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility, opening System Settings if needed.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
