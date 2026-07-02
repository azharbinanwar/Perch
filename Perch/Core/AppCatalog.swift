//
//  AppCatalog.swift
//  Perch
//
//  Lists installed apps (bundle id + name + icon) for the app picker.
//

import AppKit

enum AppCatalog {
    struct App: Identifiable {
        let id: String      // bundle id
        let name: String
        let icon: NSImage
    }

    private static var cached: [App]?

    static func installedApps() -> [App] {
        if let cached { return cached }

        let dirs = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                    NSHomeDirectory() + "/Applications"]
        let fm = FileManager.default
        var byID: [String: App] = [:]

        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let path = dir + "/" + item
                guard let bundle = Bundle(url: URL(fileURLWithPath: path)),
                      let id = bundle.bundleIdentifier, byID[id] == nil else { continue }
                byID[id] = App(id: id,
                               name: fm.displayName(atPath: path),
                               icon: NSWorkspace.shared.icon(forFile: path))
            }
        }

        let sorted = byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cached = sorted
        return sorted
    }
}
