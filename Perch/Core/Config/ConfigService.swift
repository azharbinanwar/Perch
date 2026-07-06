//
//  ConfigService.swift
//  Perch
//
//  Reads all config out of the repositories/UserDefaults into a PerchConfig (export), and
//  writes a PerchConfig back (import). File panels + a confirm live here too. After import,
//  the caller re-reads storage into the live view models via its `reload` closure.
//

import AppKit
import UniformTypeIdentifiers

private typealias K = Keys.Defaults

enum ConfigService {
    private static let defaults = UserDefaults.standard

    private static var mouseRepo: MouseRepository { ServiceLocator.shared.resolve(MouseRepository.self) }
    private static var remapRepo: RemapRepository { ServiceLocator.shared.resolve(RemapRepository.self) }
    private static var settingsRepo: SettingsRepository { ServiceLocator.shared.resolve(SettingsRepository.self) }
    private static var snippetRepo: SnippetRepository { ServiceLocator.shared.resolve(SnippetRepository.self) }
    private static var clipboardRepo: ClipboardRepository { ServiceLocator.shared.resolve(ClipboardRepository.self) }

    // MARK: - Gather / scatter

    static func export() -> PerchConfig {
        var config = PerchConfig(
            version: 1,
            settings: settingsRepo.load(),
            hotkey: .init(code: defaults.object(forKey: K.hotKeyCode) as? Int ?? 9,
                          modifiers: defaults.object(forKey: K.hotKeyModifiers) as? UInt
                              ?? NSEvent.ModifierFlags([.command, .shift]).rawValue,
                          label: defaults.string(forKey: K.hotKeyLabel) ?? "V"),
            // Hyper + Double-Tap live INSIDE each profile now — the profiles blob carries all.
            keys: .init(enabled: defaults.bool(forKey: K.remapEnabled),
                        profiles: remapRepo.loadProfiles()),
            mouse: .init(
                enabled: defaults.object(forKey: K.mouseEnabled) as? Bool ?? true,
                debounce: .init(on: defaults.bool(forKey: K.mouseDebounceOn),
                                ms: defaults.object(forKey: K.mouseDebounceMs) as? Double ?? 50),
                detected: mouseRepo.loadDetected(),
                whitelist: mouseRepo.loadWhitelist(),
                profiles: mouseRepo.loadProfiles(),   // each profile carries its scroll/pointer
                swap: defaults.bool(forKey: K.mouseSwap)),
            clipboard: .init(
                enabled: defaults.object(forKey: K.clipboardEnabled) as? Bool ?? true,
                recording: defaults.object(forKey: K.clipboardRecording) as? Bool ?? true,
                maxItems: defaults.object(forKey: K.clipboardMaxItems) as? Int ?? 50,
                autoClearMinutes: defaults.object(forKey: K.clipboardAutoClear) as? Int ?? 0,
                clearOnQuit: defaults.bool(forKey: K.clipboardClearOnQuit),
                pinLimit: defaults.object(forKey: K.clipboardPinLimit) as? Int ?? 5,
                rowDensity: defaults.string(forKey: K.clipboardRowDensity) ?? "regular",
                restoreAfterPaste: defaults.bool(forKey: K.clipboardRestoreAfterPaste),
                excludeRecord: defaults.array(forKey: K.clipboardExcludeRecord) as? [String] ?? [],
                excludeOpen: defaults.array(forKey: K.clipboardExcludeOpen) as? [String] ?? [],
                // Text only — images/files are blobs that would bloat the backup (see BackupSheet warning).
                history: clipboardRepo.load().filter { $0.content == .text }),
            snippets: snippetRepo.load())
        config.snippetExpansion = .init(on: defaults.bool(forKey: K.snippetsExpansionOn),
                                        prefix: defaults.string(forKey: K.snippetsExpansionPrefix) ?? ";",
                                        dateFormat: defaults.string(forKey: K.snippetsDateFormat),
                                        excludeApps: defaults.stringArray(forKey: K.snippetsExcludeApps))
        // Snapshot which scalar-setting keys the user actually set — the file's source of truth.
        config.presentKeys = ConfigSection.allSettingKeys.filter { defaults.object(forKey: $0) != nil }
        return config
    }

    /// Write back only the chosen sections; anything not in `sections` is left untouched on disk.
    /// Scalar settings are written only when the file lists them as set (`presentKeys`); keys the
    /// user never set are removed so storage stays sparse — the same shape a fresh install has.
    static func apply(_ c: PerchConfig, sections: Set<ConfigSection> = Set(ConfigSection.allCases)) {
        let present = Set(c.presentKeys ?? ConfigSection.allSettingKeys)   // nil (old file) → treat all as set
        func put(_ key: String, _ value: Any) {
            if present.contains(key) { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }

        if sections.contains(.general) {
            settingsRepo.save(c.settings)
            put(K.hotKeyCode, c.hotkey.code)
            put(K.hotKeyModifiers, c.hotkey.modifiers)
            put(K.hotKeyLabel, c.hotkey.label)
        }

        if sections.contains(.keys) {
            put(K.remapEnabled, c.keys.enabled)

            // Old backup files carried global hyper/double-tap — fold them into EVERY imported
            // profile (they applied everywhere, so behavior stays identical). New files carry
            // them inside each profile already.
            var profiles = c.keys.profiles
            if let h = c.keys.hyper {
                for i in profiles.indices {
                    profiles[i].hyper = HyperSettings(enabled: h.enabled, tap: h.tap,
                                                      doubleTap: h.doubleTap, shift: h.shift)
                }
            }
            if let dt = c.keys.doubleTap {
                for i in profiles.indices { profiles[i].doubleTap = dt }
            }
            remapRepo.saveProfiles(profiles)
        }

        if sections.contains(.mouse) {
            put(K.mouseEnabled, c.mouse.enabled)
            put(K.mouseDebounceOn, c.mouse.debounce.on)
            put(K.mouseDebounceMs, c.mouse.debounce.ms)
            put(K.mouseSwap, c.mouse.swap ?? false)
            mouseRepo.saveDetected(c.mouse.detected)
            mouseRepo.saveWhitelist(c.mouse.whitelist)

            // Old backup files carried global scroll/pointer — fold them into the Default profile.
            var profiles = c.mouse.profiles
            if let i = profiles.firstIndex(where: { $0.isDefault }) {
                if let s = c.mouse.scroll {
                    profiles[i].scroll = ScrollSettings(
                        reversed: s.reversed, linear: s.linear, speed: s.speed,
                        smooth: s.smooth ?? false,
                        autoOn: s.auto.on, autoButton: s.auto.button, autoSpeed: s.auto.speed)
                }
                if let p = c.mouse.pointer {
                    profiles[i].pointer = PointerSettings(override: p.override, value: p.value)
                }
            }
            mouseRepo.saveProfiles(profiles)
        }

        if sections.contains(.clipboard) {
            put(K.clipboardEnabled, c.clipboard.enabled)
            put(K.clipboardRecording, c.clipboard.recording)
            put(K.clipboardMaxItems, c.clipboard.maxItems)
            put(K.clipboardAutoClear, c.clipboard.autoClearMinutes)
            put(K.clipboardClearOnQuit, c.clipboard.clearOnQuit)
            put(K.clipboardPinLimit, c.clipboard.pinLimit)
            put(K.clipboardRowDensity, c.clipboard.rowDensity)
            put(K.clipboardRestoreAfterPaste, c.clipboard.restoreAfterPaste)
            put(K.clipboardExcludeRecord, c.clipboard.excludeRecord)
            put(K.clipboardExcludeOpen, c.clipboard.excludeOpen)
            clipboardRepo.save(c.clipboard.history)
        }

        if sections.contains(.snippets) {
            put(K.snippetsExpansionOn, c.snippetExpansion?.on ?? false)
            put(K.snippetsExpansionPrefix, c.snippetExpansion?.prefix ?? ";")
            put(K.snippetsDateFormat, c.snippetExpansion?.dateFormat ?? SnippetPlaceholders.defaultDateFormat)
            put(K.snippetsExcludeApps, c.snippetExpansion?.excludeApps ?? [])
            snippetRepo.save(c.snippets)
        }
    }

    // MARK: - Reset to default

    /// Remove a section's setting keys → each falls back to its default. (Content is untouched.)
    static func resetSettings(_ section: ConfigSection) {
        section.settingKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    /// Wipe every key under a feature namespace ("mouse.", "keys.") — settings AND content
    /// (mappings, gestures, detected buttons, profiles). Back to a fresh-install state.
    static func resetAll(prefix: String) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// A copy carrying only the chosen sections — the rest are emptied so the exported file is clean.
    static func keepingOnly(_ sections: Set<ConfigSection>, of c: PerchConfig) -> PerchConfig {
        var out = c
        if !sections.contains(.general) {
            out.settings = .default
            out.hotkey = .init(code: 9, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue, label: "V")
        }
        if !sections.contains(.keys)      { out.keys.profiles = [] }
        if !sections.contains(.mouse)     { out.mouse.profiles = []; out.mouse.detected = []; out.mouse.whitelist = [] }
        if !sections.contains(.clipboard) { out.clipboard.history = [] }
        if !sections.contains(.snippets)  { out.snippets = [] }
        return out
    }

    // MARK: - File panels

    /// Ask where to save and write the (already section-filtered) config there.
    /// The suggested name carries the export date + time so files sort and read clearly.
    static func writeToFile(_ config: PerchConfig) {
        NSApp.activate(ignoringOtherApps: true)
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH-mm"
        let panel = NSSavePanel()
        panel.title = "Export Perch Settings"
        panel.nameFieldStringValue = "Perch Config \(stamp.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Files are written in the v2 shape (meta block, hotkey under clipboard, one
        // snippets section, UI-named profile keys). Import reads v1 AND v2.
        let v2 = PerchConfigV2(config, exportedAt: stamp.string(from: Date()))
        try? encoder.encode(v2).write(to: url)
    }

    /// Show the open panel, decode, and return the config — or nil after explaining what's wrong.
    static func pickFileAndDecode() -> PerchConfig? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Import Perch Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let data = try Data(contentsOf: url)
            // A "meta" block marks a v2 file; older exports decode with the legacy shape.
            struct Probe: Codable { var meta: PerchConfigV2.Meta? }
            if (try? JSONDecoder().decode(Probe.self, from: data))?.meta != nil {
                return try JSONDecoder().decode(PerchConfigV2.self, from: data).toLegacy()
            }
            return try JSONDecoder().decode(PerchConfig.self, from: data)
        } catch {
            showInvalidFileAlert(url: url, error: error)
            return nil
        }
    }

    /// Turn a decode/read failure into a plain-language reason.
    private static func showInvalidFileAlert(url: URL, error: Error) {
        let reason: String
        switch error {
        case let DecodingError.keyNotFound(key, _):
            reason = "A required field is missing: “\(key.stringValue)”. This file may be from an incompatible version of Perch."
        case let DecodingError.typeMismatch(_, ctx), let DecodingError.valueNotFound(_, ctx):
            let path = ctx.codingPath.map(\.stringValue).joined(separator: " → ")
            reason = "A value has the wrong format\(path.isEmpty ? "" : " at “\(path)”"). The file looks corrupted or edited by hand."
        case is DecodingError:
            reason = "This isn’t a valid Perch settings file — its structure doesn’t match."
        default:
            reason = "The file couldn’t be read as JSON — it may be empty, truncated, or not a Perch settings file.\n\n\((error as NSError).localizedDescription)"
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Can’t import “\(url.lastPathComponent)”"
        alert.informativeText = reason + "\n\nNothing was changed — your current settings are untouched."
        alert.runModal()
    }
}
