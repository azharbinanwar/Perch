//
//  Constants.swift
//  Perch
//
//  All UserDefaults keys and tunable config. No raw strings inline.
//  Key format: <feature>.<field> — no per-key version; the config carries one version.
//

import Foundation

enum Keys {
    enum Defaults {
        static let clipboardHistory   = "clipboard.history"
        static let clipboardEnabled   = "clipboard.enabled"    // master: feature on/off
        static let clipboardRecording = "clipboard.recording"  // capture new copies
        static let clipboardAutoClear = "clipboard.autoClearMinutes"  // 0 = never
        static let clipboardMaxItems  = "clipboard.maxItems"
        static let clipboardClearOnQuit = "clipboard.clearOnQuit"
        static let clipboardPinLimit  = "clipboard.pinLimit"
        static let clipboardRowDensity = "clipboard.rowDensity"
        static let clipboardExcludeRecord = "clipboard.excludeRecord"  // don't record from these apps
        static let clipboardExcludeOpen   = "clipboard.excludeOpen"    // don't open ⌘⇧V over these apps
        static let clipboardRestoreAfterPaste = "clipboard.restoreAfterPaste"
        static let scrollReversed   = "mouse.scroll.reversed"
        static let scrollLinear     = "mouse.scroll.linear"    // flat, no acceleration
        static let scrollSpeed      = "mouse.scroll.speed"     // multiplier
        static let autoScrollOn     = "mouse.scroll.auto.on"          // hold button + move to scroll
        static let autoScrollButton = "mouse.scroll.auto.button"      // trigger button number
        static let autoScrollSpeed  = "mouse.scroll.auto.speed"       // sensitivity multiplier
        static let pointerOverride  = "mouse.pointer.override" // control pointer acceleration
        static let pointerValue     = "mouse.pointer.value"    // acceleration amount (0 = flat)
        static let mouseMappings    = "mouse.mappings"
        static let mouseEnabled     = "mouse.enabled"
        static let mouseWhitelist   = "mouse.whitelist"   // registered key-chord buttons
        static let mouseDetected    = "mouse.detected"    // scanned physical extra buttons
        static let mouseDebounceOn  = "mouse.debounce.on" // ignore accidental double-fires
        static let mouseDebounceMs  = "mouse.debounce.ms"
        static let mouseGestures    = "mouse.gestures"    // hold-and-move gestures (legacy/global)
        static let mouseProfiles    = "mouse.profiles"    // per-app mappings + gestures
        static let remapRules       = "keys.rules"       // legacy flat rules (migration source)
        static let remapProfiles    = "keys.profiles"    // per-app rule sets
        static let remapEnabled     = "keys.enabled"
        static let appSettings      = "settings"
        static let hotKeyCode       = "hotkey.code"
        static let hotKeyModifiers  = "hotkey.modifiers"
        static let hotKeyLabel      = "hotkey.label"
        static let snippets         = "snippets"
        static let onboarded        = "onboarded"   // first-run onboarding completed
    }
}

enum AppConfig {
    /// Max clipboard items kept in history.
    static let clipboardHistoryLimit = 50
    /// How often we check NSPasteboard for a new copy (seconds).
    static let clipboardPollInterval: TimeInterval = 0.5
    /// Bundle IDs excluded from key remapping by default (Ctrl+C must still interrupt).
    static let defaultRemapExcludedBundleIDs = ["com.apple.Terminal", "com.googlecode.iterm2"]
}
