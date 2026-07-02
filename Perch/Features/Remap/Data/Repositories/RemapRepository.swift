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
}
