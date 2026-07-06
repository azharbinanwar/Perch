//
//  ConfigSection.swift
//  Perch
//
//  The pickable slices of a PerchConfig for selective export/import. Each knows how to
//  count itself out of a config (for the dialog) and whether it actually carries anything.
//
//  Counting rule (decided with the user — driven by the file, not by comparing to defaults):
//    • count every mapping / gesture / rule in the list as-is — no per-action judgment
//    • count per-app profiles (the Default profile is always present, so it never counts)
//    • count settings the user actually SET — i.e. plist keys present in the file (`presentKeys`)
//  Reset-to-default just removes a key, so it drops out of `presentKeys` and stops counting.
//  A section "has content" when any of those parts is non-zero.
//

import Foundation

enum ConfigSection: String, CaseIterable, Identifiable {
    case general, keys, mouse, clipboard, snippets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:   "General"
        case .keys:      "Keys"
        case .mouse:     "Mouse"
        case .clipboard: "Clipboard"
        case .snippets:  "Snippets"
        }
    }

    var icon: String {
        switch self {
        case .general:   "gearshape"
        case .keys:      "keyboard"
        case .mouse:     "computermouse"
        case .clipboard: "doc.on.clipboard"
        case .snippets:  "text.quote"
        }
    }

    /// The scalar-setting plist keys this section owns. Presence of one of these in the file
    /// means the user set it. (General's app-settings blob is handled separately below.)
    var settingKeys: [String] {
        typealias K = Keys.Defaults
        switch self {
        case .general:
            return [K.settingsMenuItemCount, K.settingsOpenAtLogin,
                    K.settingsOpenWindowAtLaunch, K.settingsShowInDock,
                    K.hotKeyCode, K.hotKeyModifiers, K.hotKeyLabel]
        case .keys:
            // Hyper/double-tap moved into the per-app profiles (content) — only the master left.
            return [K.remapEnabled]
        case .mouse:
            // Scroll/pointer moved into the per-app profiles (content) — no scalar keys left.
            return [K.mouseEnabled, K.mouseSwap, K.mouseDebounceOn, K.mouseDebounceMs]
        case .clipboard:
            return [K.clipboardEnabled, K.clipboardRecording, K.clipboardAutoClear,
                    K.clipboardMaxItems, K.clipboardClearOnQuit, K.clipboardPinLimit,
                    K.clipboardRowDensity, K.clipboardExcludeRecord, K.clipboardExcludeOpen,
                    K.clipboardRestoreAfterPaste]
        case .snippets:
            return [K.snippetsExpansionOn, K.snippetsExpansionPrefix]
        }
    }

    /// Every scalar-setting key across all sections — used at export to snapshot what's set.
    static var allSettingKeys: [String] { allCases.flatMap(\.settingKeys) }

    /// The pieces shown in the dialog, e.g. ["5 mappings", "2 profiles", "3 settings changed"].
    /// Empty array → nothing to carry.
    func parts(in c: PerchConfig) -> [String] {
        func n(_ count: Int, _ noun: String) -> String { "\(count) \(noun)\(count == 1 ? "" : "s")" }
        var parts: [String] = []

        switch self {
        case .general:
            break   // settings-only (added below)

        case .keys:
            let rules = c.keys.profiles.reduce(0) { $0 + $1.rules.count }
            let apps  = c.keys.profiles.filter { $0.appBundleID != nil }.count
            if rules > 0 { parts.append(n(rules, "mapping")) }
            if apps  > 0 { parts.append(n(apps, "profile")) }

        case .mouse:
            let maps  = c.mouse.profiles.reduce(0) { $0 + $1.mappings.count }
            let gests = c.mouse.profiles.reduce(0) { $0 + $1.gestures.count }
            let apps  = c.mouse.profiles.filter { $0.appBundleID != nil }.count
            if maps  > 0 { parts.append(n(maps, "mapping")) }
            if gests > 0 { parts.append(n(gests, "gesture")) }
            if apps  > 0 { parts.append(n(apps, "profile")) }

        case .clipboard:
            let items = c.clipboard.history.count
            if items > 0 { parts.append(n(items, "item")) }

        case .snippets:
            let s = c.snippets.count
            if s > 0 { parts.append(n(s, "snippet")) }
        }

        let changed = settingsChanged(in: c)
        if changed > 0 { parts.append("\(n(changed, "setting")) changed") }
        return parts
    }

    /// One-line label for the dialog.
    func summary(in c: PerchConfig) -> String {
        let p = parts(in: c)
        return p.isEmpty ? "" : p.joined(separator: " · ")
    }

    /// False when there's nothing to carry — the dialog greys these out and won't select them.
    func hasContent(in c: PerchConfig) -> Bool { !parts(in: c).isEmpty }

    /// How many of this section's settings the user actually set — read from the file's manifest.
    private func settingsChanged(in c: PerchConfig) -> Int {
        let present = Set(c.presentKeys ?? [])
        // The clipboard shortcut is three keys (code/modifiers/label) but reads as one setting.
        let hotkeyKeys = [Keys.Defaults.hotKeyCode, Keys.Defaults.hotKeyModifiers, Keys.Defaults.hotKeyLabel]
        var count = settingKeys.filter { !hotkeyKeys.contains($0) }.filter(present.contains).count
        if hotkeyKeys.contains(where: present.contains) { count += 1 }
        return count
    }
}
