//
//  PerchConfig.swift
//  Perch
//
//  One portable snapshot of all app *config* (not clipboard history / image blobs).
//  Shaped like the export JSON and reuses the existing Codable entities, so export/import
//  is just encode/decode — no field-by-field mapping.
//

import Foundation

struct PerchConfig: Codable {
    var version: Int
    var settings: AppSettings
    var hotkey: Hotkey
    var keys: KeysCfg
    var mouse: MouseCfg
    var clipboard: ClipboardCfg
    var snippets: [Snippet]

    /// The scalar-setting plist keys that actually existed at export time. This is the single
    /// source of truth for "what did the user set" — counting reads this instead of comparing
    /// each value to a default. Absent (nil) in files from before this existed → treated as none.
    var presentKeys: [String]? = nil
}

extension PerchConfig {
    struct Hotkey: Codable {
        var code: Int
        var modifiers: UInt
        var label: String
    }

    struct KeysCfg: Codable {
        var enabled: Bool
        var profiles: [RemapProfile]
    }

    struct MouseCfg: Codable {
        var enabled: Bool
        var debounce: Debounce
        var detected: [MouseTrigger]
        var whitelist: [MouseTrigger]
        var profiles: [MouseProfile]
        var scroll: Scroll
        var pointer: Pointer

        struct Debounce: Codable { var on: Bool; var ms: Double }
        struct Scroll: Codable { var reversed: Bool; var linear: Bool; var speed: Double; var auto: Auto }
        struct Auto: Codable { var on: Bool; var button: Int; var speed: Double }
        struct Pointer: Codable { var override: Bool; var value: Double }
    }

    struct ClipboardCfg: Codable {
        var enabled: Bool
        var recording: Bool
        var maxItems: Int
        var autoClearMinutes: Int
        var clearOnQuit: Bool
        var pinLimit: Int
        var rowDensity: String
        var restoreAfterPaste: Bool
        var excludeRecord: [String]
        var excludeOpen: [String]
        var history: [ClipboardItem]   // the saved list; import restores it without touching the system clipboard
    }
}
