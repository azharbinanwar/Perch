//
//  RemapProfile.swift
//  Perch
//
//  A set of key-remap rules scoped to one app (or the Default, which applies to every app
//  without its own profile). The active profile follows the frontmost app.
//

import Foundation

struct RemapProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var appBundleID: String?          // nil = Default (all other apps)
    var appName: String?
    var rules: [RemapRule] = []

    var isDefault: Bool { appBundleID == nil }
    var displayName: String { appName ?? (isDefault ? "Default" : (appBundleID ?? "App")) }

    init(id: UUID = UUID(), appBundleID: String? = nil, appName: String? = nil, rules: [RemapRule] = []) {
        self.id = id
        self.appBundleID = appBundleID
        self.appName = appName
        self.rules = rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        appBundleID = try? c.decode(String.self, forKey: .appBundleID)
        appName = try? c.decode(String.self, forKey: .appName)
        rules = (try? c.decode([RemapRule].self, forKey: .rules)) ?? []
    }
}
