//
//  RemapRepository.swift
//  Perch
//

import Foundation

final class RemapRepository {
    private let defaults = UserDefaults.standard

    /// Loads saved rules, seeding the defaults on first launch.
    func load() -> [RemapRule] {
        guard let data = defaults.data(forKey: Keys.Defaults.remapRules),
              let rules = try? JSONDecoder().decode([RemapRule].self, from: data) else {
            return RemapRule.defaults
        }
        return rules
    }

    func save(_ rules: [RemapRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Keys.Defaults.remapRules)
    }

    // MARK: - Per-app profiles

    /// Load profiles; always contains a Default. First run folds any old flat rules into Default.
    func loadProfiles() -> [RemapProfile] {
        if let data = defaults.data(forKey: Keys.Defaults.remapProfiles),
           let profiles = try? JSONDecoder().decode([RemapProfile].self, from: data),
           profiles.contains(where: { $0.isDefault }) {
            return migrateGlobalHyperDoubleTap(profiles)
        }
        let migrated = RemapProfile(appBundleID: nil, appName: "Default", rules: load())
        saveProfiles([migrated])
        return migrateGlobalHyperDoubleTap([migrated])
    }

    /// One-time migration: Hyper Key and Double-Tap used to be single global keys. Fold them
    /// into EVERY profile (they applied everywhere, so behavior stays identical), then delete
    /// the old keys so they never migrate twice.
    private func migrateGlobalHyperDoubleTap(_ profiles: [RemapProfile]) -> [RemapProfile] {
        typealias K = Keys.Defaults
        let hadHyper = defaults.object(forKey: K.hyperEnabled) != nil
            || defaults.object(forKey: K.hyperTap) != nil
            || defaults.object(forKey: K.hyperShift) != nil
        let oldDoubleTap = defaults.data(forKey: K.doubleTap)
            .flatMap { try? JSONDecoder().decode(DoubleTapConfig.self, from: $0) }
        guard hadHyper || oldDoubleTap != nil else { return profiles }

        var out = profiles
        let hyper = HyperSettings(
            enabled: defaults.bool(forKey: K.hyperEnabled),
            tap: defaults.string(forKey: K.hyperTap) ?? "Escape",
            doubleTap: defaults.string(forKey: K.hyperDoubleTap) ?? "Caps Lock",
            shift: defaults.object(forKey: K.hyperShift) as? Bool ?? true)
        for i in out.indices {
            if hadHyper { out[i].hyper = hyper }
            if let dt = oldDoubleTap { out[i].doubleTap = dt }
        }
        [K.hyperEnabled, K.hyperTap, K.hyperDoubleTap, K.hyperShift, K.doubleTap]
            .forEach { defaults.removeObject(forKey: $0) }
        saveProfiles(out)
        return out
    }

    func saveProfiles(_ profiles: [RemapProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Keys.Defaults.remapProfiles)
    }
}
