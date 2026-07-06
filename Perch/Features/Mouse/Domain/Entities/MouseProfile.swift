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

/// One shift key with its OWN combo set. Every combo (hold key + button + action) lives in
/// its hold key's list — b4+left can do something different from b5+left, unlimited combos.
struct HoldLayer: Codable, Equatable {
    var hold: MouseTrigger
    var mappings: [MouseMapping] = []   // may include .button(0)/(1) — left/right are legal here

    init(hold: MouseTrigger, mappings: [MouseMapping] = []) {
        self.hold = hold
        self.mappings = mappings
    }
}

/// Mouse Shift: hold a shift key → other buttons run THAT key's combo set.
struct LayerConfig: Codable, Equatable {
    var enabled = false
    var layers: [HoldLayer] = []   // one entry per shift key, each saved independently

    static let `default` = LayerConfig()

    init() {}
    init(enabled: Bool, layers: [HoldLayer]) {
        self.enabled = enabled
        self.layers = layers
    }

    /// The combo set for one shift key ([] when none saved yet).
    func mappings(for hold: MouseTrigger) -> [MouseMapping] {
        layers.first { $0.hold == hold }?.mappings ?? []
    }

    enum CodingKeys: String, CodingKey { case enabled, layers, holdTriggers, mappings, holdTrigger }

    // Lenient decode — migrates both older schemas (shared mappings list, single hold key).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        if let list = try c.decodeIfPresent([HoldLayer].self, forKey: .layers) {
            layers = list
        } else {
            let shared = try c.decodeIfPresent([MouseMapping].self, forKey: .mappings) ?? []
            let holds: [MouseTrigger]
            if let many = try c.decodeIfPresent([MouseTrigger].self, forKey: .holdTriggers) {
                holds = many
            } else if let one = try c.decodeIfPresent(MouseTrigger.self, forKey: .holdTrigger) {
                holds = [one]
            } else {
                holds = []
            }
            layers = holds.map { HoldLayer(hold: $0, mappings: shared) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(layers, forKey: .layers)
    }
}

struct MouseProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var appBundleID: String?          // nil = Default (all other apps)
    var appName: String?
    var mappings: [MouseMapping] = []
    var gestures: [MouseGesture] = []
    var scroll: ScrollSettings = .default
    var pointer: PointerSettings = .default
    var layer: LayerConfig = .default

    var isDefault: Bool { appBundleID == nil }
    var displayName: String { appName ?? (isDefault ? "Default" : (appBundleID ?? "App")) }

    init(id: UUID = UUID(), appBundleID: String? = nil, appName: String? = nil,
         mappings: [MouseMapping] = [], gestures: [MouseGesture] = [],
         scroll: ScrollSettings = .default, pointer: PointerSettings = .default,
         layer: LayerConfig = .default) {
        self.id = id
        self.appBundleID = appBundleID
        self.appName = appName
        self.mappings = mappings
        self.gestures = gestures
        self.scroll = scroll
        self.pointer = pointer
        self.layer = layer
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
        layer = (try? c.decode(LayerConfig.self, forKey: .layer)) ?? .default
    }
}
