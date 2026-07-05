//
//  MouseProfile.swift
//  Perch
//
//  Everything mouse, scoped to one app (or the Default, which applies to every app without
//  its own profile): button mappings + gestures AND the scroll/pointer settings. The active
//  profile follows the frontmost app.
//

import Foundation

/// The modifier held for turbo scroll. rawValue is both the stored and shown string.
enum TurboKey: String, Codable, CaseIterable, Identifiable {
    case option = "⌥ Option"
    case command = "⌘ Command"
    case control = "⌃ Control"
    var id: String { rawValue }
}

/// Scroll behavior for one profile (reverse / flat / speed / smooth / turbo / auto-scroll).
struct ScrollSettings: Codable, Equatable {
    var reversed = false
    var linear = false
    var speed: Double = 1
    var smooth = false
    var turboOn = false
    var turboKey: TurboKey = .option
    var turboSpeed: Double = 4
    var autoOn = false
    var autoButton = 2
    var autoSpeed: Double = 1

    static let `default` = ScrollSettings()

    // Lenient decode — settings saved before newer fields existed keep loading.
    init() {}
    init(reversed: Bool = false, linear: Bool = false, speed: Double = 1, smooth: Bool = false,
         turboOn: Bool = false, turboKey: TurboKey = .option, turboSpeed: Double = 4,
         autoOn: Bool = false, autoButton: Int = 2, autoSpeed: Double = 1) {
        self.reversed = reversed
        self.linear = linear
        self.speed = speed
        self.smooth = smooth
        self.turboOn = turboOn
        self.turboKey = turboKey
        self.turboSpeed = turboSpeed
        self.autoOn = autoOn
        self.autoButton = autoButton
        self.autoSpeed = autoSpeed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reversed = try c.decodeIfPresent(Bool.self, forKey: .reversed) ?? false
        linear = try c.decodeIfPresent(Bool.self, forKey: .linear) ?? false
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        smooth = try c.decodeIfPresent(Bool.self, forKey: .smooth) ?? false
        turboOn = try c.decodeIfPresent(Bool.self, forKey: .turboOn) ?? false
        turboKey = try c.decodeIfPresent(TurboKey.self, forKey: .turboKey) ?? .option
        turboSpeed = try c.decodeIfPresent(Double.self, forKey: .turboSpeed) ?? 4
        autoOn = try c.decodeIfPresent(Bool.self, forKey: .autoOn) ?? false
        autoButton = try c.decodeIfPresent(Int.self, forKey: .autoButton) ?? 2
        autoSpeed = try c.decodeIfPresent(Double.self, forKey: .autoSpeed) ?? 1
    }
}

/// Pointer acceleration for one profile (off = macOS untouched).
struct PointerSettings: Codable, Equatable {
    var override = false
    var value: Double = 0

    static let `default` = PointerSettings()
}

struct MouseProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var appBundleID: String?          // nil = Default (all other apps)
    var appName: String?
    var mappings: [MouseMapping] = []
    var gestures: [MouseGesture] = []
    var scroll: ScrollSettings = .default
    var pointer: PointerSettings = .default

    var isDefault: Bool { appBundleID == nil }
    var displayName: String { appName ?? (isDefault ? "Default" : (appBundleID ?? "App")) }

    init(id: UUID = UUID(), appBundleID: String? = nil, appName: String? = nil,
         mappings: [MouseMapping] = [], gestures: [MouseGesture] = [],
         scroll: ScrollSettings = .default, pointer: PointerSettings = .default) {
        self.id = id
        self.appBundleID = appBundleID
        self.appName = appName
        self.mappings = mappings
        self.gestures = gestures
        self.scroll = scroll
        self.pointer = pointer
    }

    // Lenient decode so older/partial payloads still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        appBundleID = try? c.decode(String.self, forKey: .appBundleID)
        appName = try? c.decode(String.self, forKey: .appName)
        mappings = (try? c.decode([MouseMapping].self, forKey: .mappings)) ?? []
        gestures = (try? c.decode([MouseGesture].self, forKey: .gestures)) ?? []
        scroll = (try? c.decode(ScrollSettings.self, forKey: .scroll)) ?? .default
        pointer = (try? c.decode(PointerSettings.self, forKey: .pointer)) ?? .default
    }
}
