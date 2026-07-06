//
//  PerchConfigV2.swift
//  Perch
//
//  The v2 EXPORT FILE shape — organized the way the app reads: meta bookkeeping in its own
//  block, hotkey under clipboard, snippets as one section, and profile contents named with
//  the UI's words (buttons, mouseShift, holdKeys, combos, shortcuts). Internal storage is
//  untouched: this converts to/from the legacy PerchConfig, and import still reads v1 files.
//

import Foundation

struct PerchConfigV2: Codable {

    struct Meta: Codable {
        var version = 2
        var exportedAt: String? = nil
        var presentKeys: [String]? = nil   // which scalar settings the user actually set
    }

    /// bundleID nil = the Default profile (applies to every app without its own).
    struct AppRef: Codable {
        var bundleID: String?
        var name: String?
    }

    struct ClipboardSection: Codable {
        struct Settings: Codable {
            var enabled: Bool
            var recording: Bool
            var maxItems: Int
            var autoClearMinutes: Int
            var clearOnQuit: Bool
            var pinLimit: Int
            var rowDensity: String
            var restoreAfterPaste: Bool
            var hotkey: PerchConfig.Hotkey       // opens the clipboard popup — lives here now
            var excludeRecord: [String]
            var excludeOpen: [String]
        }
        var settings: Settings
        var history: [ClipboardItem]
    }

    struct KeysSection: Codable {
        struct Profile: Codable {
            var app: AppRef
            var shortcuts: [RemapRule]
            var hyperKey: HyperSettings
            var doubleTap: DoubleTapConfig
        }
        var enabled: Bool
        var profiles: [Profile]
    }

    struct MouseSection: Codable {
        struct Reliability: Codable {
            var debounceOn: Bool
            var debounceMs: Double
        }
        struct HoldKey: Codable {
            var hold: MouseTrigger
            var combos: [MouseMapping]
        }
        struct Shift: Codable {
            var enabled: Bool
            var holdKeys: [HoldKey]
        }
        struct Profile: Codable {
            var app: AppRef
            var buttons: [MouseMapping]
            var gestures: [MouseGesture]
            var scroll: ScrollSettings
            var pointer: PointerSettings
            var mouseShift: Shift
        }
        var enabled: Bool
        var swap: Bool
        var reliability: Reliability
        var detectedButtons: [MouseTrigger]
        var keystrokeButtons: [MouseTrigger]
        var profiles: [Profile]
    }

    struct SnippetsSection: Codable {
        struct Settings: Codable {
            var expansionOn: Bool
            var prefix: String
            var dateFormat: String?
            var excludeApps: [String]?
        }
        var settings: Settings
        var items: [Snippet]
    }

    var meta: Meta
    var general: AppSettings
    var clipboard: ClipboardSection
    var keys: KeysSection
    var mouse: MouseSection
    var snippets: SnippetsSection
}

// MARK: - Converters (legacy PerchConfig stays the app's working model)

extension PerchConfigV2 {

    init(_ c: PerchConfig, exportedAt: String) {
        meta = Meta(version: 2, exportedAt: exportedAt, presentKeys: c.presentKeys)
        general = c.settings
        clipboard = ClipboardSection(
            settings: .init(enabled: c.clipboard.enabled,
                            recording: c.clipboard.recording,
                            maxItems: c.clipboard.maxItems,
                            autoClearMinutes: c.clipboard.autoClearMinutes,
                            clearOnQuit: c.clipboard.clearOnQuit,
                            pinLimit: c.clipboard.pinLimit,
                            rowDensity: c.clipboard.rowDensity,
                            restoreAfterPaste: c.clipboard.restoreAfterPaste,
                            hotkey: c.hotkey,
                            excludeRecord: c.clipboard.excludeRecord,
                            excludeOpen: c.clipboard.excludeOpen),
            history: c.clipboard.history)
        keys = KeysSection(
            enabled: c.keys.enabled,
            profiles: c.keys.profiles.map { p in
                .init(app: AppRef(bundleID: p.appBundleID, name: p.appName),
                      shortcuts: p.rules, hyperKey: p.hyper, doubleTap: p.doubleTap)
            })
        mouse = MouseSection(
            enabled: c.mouse.enabled,
            swap: c.mouse.swap ?? false,
            reliability: .init(debounceOn: c.mouse.debounce.on, debounceMs: c.mouse.debounce.ms),
            detectedButtons: c.mouse.detected,
            keystrokeButtons: c.mouse.whitelist,
            profiles: c.mouse.profiles.map { p in
                .init(app: AppRef(bundleID: p.appBundleID, name: p.appName),
                      buttons: p.mappings, gestures: p.gestures,
                      scroll: p.scroll, pointer: p.pointer,
                      mouseShift: MouseSection.Shift(enabled: p.layer.enabled,
                                                     holdKeys: p.layer.layers.map { .init(hold: $0.hold, combos: $0.mappings) }))
            })
        snippets = SnippetsSection(
            settings: .init(expansionOn: c.snippetExpansion?.on ?? false,
                            prefix: c.snippetExpansion?.prefix ?? ";",
                            dateFormat: c.snippetExpansion?.dateFormat,
                            excludeApps: c.snippetExpansion?.excludeApps),
            items: c.snippets)
    }

    /// Back to the working model — apply/counting/sections all keep operating on PerchConfig.
    func toLegacy() -> PerchConfig {
        var c = PerchConfig(
            version: 1,
            settings: general,
            hotkey: clipboard.settings.hotkey,
            keys: .init(enabled: keys.enabled,
                        profiles: keys.profiles.map { p in
                            RemapProfile(appBundleID: p.app.bundleID, appName: p.app.name,
                                         rules: p.shortcuts, hyper: p.hyperKey, doubleTap: p.doubleTap)
                        }),
            mouse: .init(enabled: mouse.enabled,
                         debounce: .init(on: mouse.reliability.debounceOn, ms: mouse.reliability.debounceMs),
                         detected: mouse.detectedButtons,
                         whitelist: mouse.keystrokeButtons,
                         profiles: mouse.profiles.map { p in
                             MouseProfile(appBundleID: p.app.bundleID, appName: p.app.name,
                                          mappings: p.buttons, gestures: p.gestures,
                                          scroll: p.scroll, pointer: p.pointer,
                                          layer: LayerConfig(enabled: p.mouseShift.enabled,
                                                             layers: p.mouseShift.holdKeys.map {
                                                                 HoldLayer(hold: $0.hold, mappings: $0.combos)
                                                             }))
                         },
                         swap: mouse.swap),
            clipboard: .init(enabled: clipboard.settings.enabled,
                             recording: clipboard.settings.recording,
                             maxItems: clipboard.settings.maxItems,
                             autoClearMinutes: clipboard.settings.autoClearMinutes,
                             clearOnQuit: clipboard.settings.clearOnQuit,
                             pinLimit: clipboard.settings.pinLimit,
                             rowDensity: clipboard.settings.rowDensity,
                             restoreAfterPaste: clipboard.settings.restoreAfterPaste,
                             excludeRecord: clipboard.settings.excludeRecord,
                             excludeOpen: clipboard.settings.excludeOpen,
                             history: clipboard.history),
            snippets: snippets.items)
        c.snippetExpansion = .init(on: snippets.settings.expansionOn,
                                   prefix: snippets.settings.prefix,
                                   dateFormat: snippets.settings.dateFormat,
                                   excludeApps: snippets.settings.excludeApps)
        c.presentKeys = meta.presentKeys
        return c
    }
}
