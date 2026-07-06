//
//  RemapProfile.swift
//  Perch
//
//  Everything Keys, scoped to one app (or the Default, which applies to every app without
//  its own profile): remap rules AND the Hyper Key + Double-Tap settings. The active profile
//  follows the frontmost app — so Caps Lock can stay Caps Lock in a terminal while being
//  Hyper everywhere else.
//

import Foundation

/// Hyper Key settings for one profile. Tap values store HyperKeyManager.TapAction rawValues.
struct HyperSettings: Codable, Equatable {
    var enabled = false
    var tap = "Escape"
    var doubleTap = "Caps Lock"
    var shift = true

    static let `default` = HyperSettings()

    init() {}
    init(enabled: Bool, tap: String, doubleTap: String, shift: Bool) {
        self.enabled = enabled
        self.tap = tap
        self.doubleTap = doubleTap
        self.shift = shift
    }

    // Lenient decode so older/partial payloads still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        tap = try c.decodeIfPresent(String.self, forKey: .tap) ?? "Escape"
        doubleTap = try c.decodeIfPresent(String.self, forKey: .doubleTap) ?? "Caps Lock"
        shift = try c.decodeIfPresent(Bool.self, forKey: .shift) ?? true
    }
}

struct RemapProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var appBundleID: String?          // nil = Default (all other apps)
    var appName: String?
    var rules: [RemapRule] = []
    var hyper: HyperSettings = .default
    var doubleTap: DoubleTapConfig = .default

    var isDefault: Bool { appBundleID == nil }
    var displayName: String { appName ?? (isDefault ? "Default" : (appBundleID ?? "App")) }

    init(id: UUID = UUID(), appBundleID: String? = nil, appName: String? = nil,
         rules: [RemapRule] = [], hyper: HyperSettings = .default,
         doubleTap: DoubleTapConfig = .default) {
        self.id = id
        self.appBundleID = appBundleID
        self.appName = appName
        self.rules = rules
        self.hyper = hyper
        self.doubleTap = doubleTap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        appBundleID = try? c.decode(String.self, forKey: .appBundleID)
        appName = try? c.decode(String.self, forKey: .appName)
        rules = (try? c.decode([RemapRule].self, forKey: .rules)) ?? []
        hyper = (try? c.decode(HyperSettings.self, forKey: .hyper)) ?? .default
        doubleTap = (try? c.decode(DoubleTapConfig.self, forKey: .doubleTap)) ?? .default
    }
}
