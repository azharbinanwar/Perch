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
            return profiles
        }
        let migrated = RemapProfile(appBundleID: nil, appName: "Default", rules: load())
        saveProfiles([migrated])
        return [migrated]
    }

    func saveProfiles(_ profiles: [RemapProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Keys.Defaults.remapProfiles)
    }
}
