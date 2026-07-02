//
//  AppIcon.swift
//  Perch
//
//  Cached lookup of an app's icon by bundle id — the system already caches icons,
//  and we cache the NSImage per id so rendering a long list stays fast.
//

import AppKit

enum AppIcon {
    private static var iconCache: [String: NSImage] = [:]
    private static var nameCache: [String: String] = [:]

    static func forBundleID(_ id: String?) -> NSImage? {
        guard let id else { return nil }
        if let cached = iconCache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[id] = icon
        return icon
    }

    /// Display name of the app (e.g. "WhatsApp"), cached. Used for search.
    static func name(forBundleID id: String?) -> String? {
        guard let id else { return nil }
        if let cached = nameCache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        nameCache[id] = name
        return name
    }
}
