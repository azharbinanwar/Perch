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
        static let scrollReversed   = "dev.perch.scroll.reversed.v1"
        static let remapRules       = "dev.perch.remap.rules.v1"
        static let remapEnabled     = "dev.perch.remap.enabled.v1"
        static let appSettings      = "dev.perch.settings.v1"
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
