//
//  MouseProfile.swift
//  Perch
//
//  A set of button mappings + gestures scoped to one app (or the Default, which applies to
//  every app without its own profile). The active profile follows the frontmost app.
//

import Foundation

struct MouseProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var appBundleID: String?          // nil = Default (all other apps)
    var appName: String?
    var mappings: [MouseMapping] = []
    var gestures: [MouseGesture] = []

    var isDefault: Bool { appBundleID == nil }
    var displayName: String { appName ?? (isDefault ? "Default" : (appBundleID ?? "App")) }

    init(id: UUID = UUID(), appBundleID: String? = nil, appName: String? = nil,
         mappings: [MouseMapping] = [], gestures: [MouseGesture] = []) {
        self.id = id
        self.appBundleID = appBundleID
        self.appName = appName
        self.mappings = mappings
        self.gestures = gestures
    }

    // Lenient decode so older/partial payloads still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        appBundleID = try? c.decode(String.self, forKey: .appBundleID)
        appName = try? c.decode(String.self, forKey: .appName)
        mappings = (try? c.decode([MouseMapping].self, forKey: .mappings)) ?? []
        gestures = (try? c.decode([MouseGesture].self, forKey: .gestures)) ?? []
    }
}
