//
//  Constants.swift
//  Perch
//
//  All UserDefaults keys and tunable config. No raw strings inline.
//  Key format: dev.perch.<name>.vN — bump vN when stored format changes.
//

import Foundation

enum Keys {
    enum Defaults {
        static let clipboardHistory   = "dev.perch.clipboard.history.v1"
        static let clipboardEnabled   = "dev.perch.clipboard.enabled.v1"    // master: feature on/off
        static let clipboardRecording = "dev.perch.clipboard.recording.v1"  // capture new copies
        static let clipboardAutoClear = "dev.perch.clipboard.autoClearMinutes.v1"  // 0 = never
        static let clipboardMaxItems  = "dev.perch.clipboard.maxItems.v1"
        static let clipboardClearOnQuit = "dev.perch.clipboard.clearOnQuit.v1"
        static let clipboardPinLimit  = "dev.perch.clipboard.pinLimit.v1"
        static let clipboardRowDensity = "dev.perch.clipboard.rowDensity.v1"
        static let clipboardExcludeRecord = "dev.perch.clipboard.excludeRecord.v1"  // don't record from these apps
        static let clipboardExcludeOpen   = "dev.perch.clipboard.excludeOpen.v1"    // don't open ⌘⇧V over these apps
        static let clipboardRestoreAfterPaste = "dev.perch.clipboard.restoreAfterPaste.v1"
        static let scrollReversed   = "dev.perch.scroll.reversed.v1"
        static let scrollLinear     = "dev.perch.scroll.linear.v1"    // flat, no acceleration
        static let scrollSpeed      = "dev.perch.scroll.speed.v1"     // multiplier
        static let autoScrollOn     = "dev.perch.scroll.auto.on.v1"          // hold button + move to scroll
        static let autoScrollButton = "dev.perch.scroll.auto.button.v1"      // trigger button number
        static let autoScrollSpeed  = "dev.perch.scroll.auto.speed.v1"       // sensitivity multiplier
        static let pointerOverride  = "dev.perch.pointer.override.v1" // control pointer acceleration
        static let pointerValue     = "dev.perch.pointer.value.v1"    // acceleration amount (0 = flat)
        static let mouseMappings    = "dev.perch.mouse.mappings.v1"
        static let mouseEnabled     = "dev.perch.mouse.enabled.v1"
        static let mouseWhitelist   = "dev.perch.mouse.whitelist.v1"   // registered key-chord buttons
        static let mouseDetected    = "dev.perch.mouse.detected.v1"    // scanned physical extra buttons
        static let mouseDebounceOn  = "dev.perch.mouse.debounce.on.v1" // ignore accidental double-fires
        static let mouseDebounceMs  = "dev.perch.mouse.debounce.ms.v1"
        static let mouseGestures    = "dev.perch.mouse.gestures.v1"    // hold-and-move gestures (legacy/global)
        static let mouseProfiles    = "dev.perch.mouse.profiles.v1"    // per-app mappings + gestures
        static let remapRules       = "dev.perch.remap.rules.v2"   // v2: general input→output combos (legacy/migration)
        static let remapProfiles    = "dev.perch.remap.profiles.v1"  // per-app rule sets
        static let remapEnabled     = "dev.perch.remap.enabled.v1"
        static let appSettings      = "dev.perch.settings.v1"
        static let hotKeyCode       = "dev.perch.hotkey.code.v1"
        static let hotKeyModifiers  = "dev.perch.hotkey.modifiers.v1"
        static let hotKeyLabel      = "dev.perch.hotkey.label.v1"
        static let snippets         = "dev.perch.snippets.v1"
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
