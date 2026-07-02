//
//  SettingsRepository.swift
//  Perch
//

import Foundation

final class SettingsRepository {
    private let defaults = UserDefaults.standard

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: Keys.Defaults.appSettings),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Keys.Defaults.appSettings)
    }
}
