//
//  MouseRepository.swift
//  Perch
//
//  Persists mouse button mappings to UserDefaults (JSON), same pattern as the other repos.
//

import Foundation

final class MouseRepository {
    private let defaults = UserDefaults.standard

    func load() -> [MouseMapping] {
        guard let data = defaults.data(forKey: Keys.Defaults.mouseMappings),
              let mappings = try? JSONDecoder().decode([MouseMapping].self, from: data) else {
            return []
        }
        return mappings
    }

    func save(_ mappings: [MouseMapping]) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        defaults.set(data, forKey: Keys.Defaults.mouseMappings)
    }

    // Whitelisted key-chord buttons the user registered.
    func loadWhitelist() -> [MouseTrigger] {
        guard let data = defaults.data(forKey: Keys.Defaults.mouseWhitelist),
              let list = try? JSONDecoder().decode([MouseTrigger].self, from: data) else {
            return []
        }
        return list
    }

    func saveWhitelist(_ list: [MouseTrigger]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Keys.Defaults.mouseWhitelist)
    }

    // Scanned physical extra buttons (so the user doesn't re-scan every launch).
    func loadDetected() -> [MouseTrigger] {
        guard let data = defaults.data(forKey: Keys.Defaults.mouseDetected),
              let list = try? JSONDecoder().decode([MouseTrigger].self, from: data) else {
            return []
        }
        return list
    }

    func saveDetected(_ list: [MouseTrigger]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Keys.Defaults.mouseDetected)
    }

    func loadGestures() -> [MouseGesture] {
        guard let data = defaults.data(forKey: Keys.Defaults.mouseGestures),
              let list = try? JSONDecoder().decode([MouseGesture].self, from: data) else {
            return []
        }
        return list
    }

    func saveGestures(_ list: [MouseGesture]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Keys.Defaults.mouseGestures)
    }

    // MARK: - Per-app profiles

    /// Load profiles; always contains a Default. First run migrates the old global
    /// mappings/gestures into the Default profile.
    func loadProfiles() -> [MouseProfile] {
        if let data = defaults.data(forKey: Keys.Defaults.mouseProfiles),
           let profiles = try? JSONDecoder().decode([MouseProfile].self, from: data),
           profiles.contains(where: { $0.isDefault }) {
            return migrateScrollPointerIfNeeded(profiles)
        }
        let migrated = MouseProfile(appBundleID: nil, appName: "Default",
                                    mappings: load(), gestures: loadGestures())
        saveProfiles([migrated])
        return migrateScrollPointerIfNeeded([migrated])
    }

    /// One-time: scroll/pointer used to be global plist keys — fold them into the Default
    /// profile, then remove the old keys. Idempotent (the keys are gone after the first run).
    private func migrateScrollPointerIfNeeded(_ profiles: [MouseProfile]) -> [MouseProfile] {
        typealias K = Keys.Defaults
        let legacyKeys = [K.scrollReversed, K.scrollLinear, K.scrollSpeed, K.scrollSmooth,
                          K.autoScrollOn, K.autoScrollButton, K.autoScrollSpeed,
                          K.pointerOverride, K.pointerValue]
        guard legacyKeys.contains(where: { defaults.object(forKey: $0) != nil }),
              let i = profiles.firstIndex(where: { $0.isDefault }) else { return profiles }

        var migrated = profiles
        migrated[i].scroll = ScrollSettings(
            reversed: defaults.bool(forKey: K.scrollReversed),
            linear: defaults.bool(forKey: K.scrollLinear),
            speed: defaults.object(forKey: K.scrollSpeed) as? Double ?? 1,
            smooth: defaults.bool(forKey: K.scrollSmooth),
            autoOn: defaults.bool(forKey: K.autoScrollOn),
            autoButton: defaults.object(forKey: K.autoScrollButton) as? Int ?? 2,
            autoSpeed: defaults.object(forKey: K.autoScrollSpeed) as? Double ?? 1)
        migrated[i].pointer = PointerSettings(
            override: defaults.bool(forKey: K.pointerOverride),
            value: defaults.object(forKey: K.pointerValue) as? Double ?? 0)
        legacyKeys.forEach { defaults.removeObject(forKey: $0) }
        saveProfiles(migrated)
        return migrated
    }

    func saveProfiles(_ profiles: [MouseProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Keys.Defaults.mouseProfiles)
    }
}
