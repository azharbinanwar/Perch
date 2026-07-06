//
//  SettingsRepository.swift
//  Perch
//
//  Stores each app-setting as its own plist key (not one blob), sparse: a field is written only
//  when it differs from the default, and removed when reset to default. So "key exists = the user
//  set it" — the same rule export/import counting relies on.
//

import Foundation

final class SettingsRepository {
    private let defaults = UserDefaults.standard
    private typealias K = Keys.Defaults

    func load() -> AppSettings {
        // One-time migration: fold the old single blob into individual keys, then drop it.
        if let data = defaults.data(forKey: K.appSettings),
           let old = try? JSONDecoder().decode(AppSettings.self, from: data) {
            save(old)
            defaults.removeObject(forKey: K.appSettings)
            return old
        }

        let d = AppSettings.default
        return AppSettings(
            menuItemCount:      defaults.object(forKey: K.settingsMenuItemCount) as? Int ?? d.menuItemCount,
            openAtLogin:        defaults.object(forKey: K.settingsOpenAtLogin) as? Bool ?? d.openAtLogin,
            openWindowAtLaunch: defaults.object(forKey: K.settingsOpenWindowAtLaunch) as? Bool ?? d.openWindowAtLaunch,
            showInDock:         defaults.object(forKey: K.settingsShowInDock) as? Bool ?? d.showInDock,
            theme:              AppTheme(rawValue: defaults.string(forKey: K.settingsTheme) ?? "") ?? d.theme)
    }

    func save(_ settings: AppSettings) {
        let d = AppSettings.default
        setOrClear(K.settingsMenuItemCount, settings.menuItemCount, default: d.menuItemCount)
        setOrClear(K.settingsOpenAtLogin, settings.openAtLogin, default: d.openAtLogin)
        setOrClear(K.settingsOpenWindowAtLaunch, settings.openWindowAtLaunch, default: d.openWindowAtLaunch)
        setOrClear(K.settingsShowInDock, settings.showInDock, default: d.showInDock)
        setOrClear(K.settingsTheme, settings.theme.rawValue, default: d.theme.rawValue)
    }

    /// Write the value only if it differs from the default; otherwise remove the key (stays sparse).
    private func setOrClear<T: Equatable>(_ key: String, _ value: T, default def: T) {
        if value == def { defaults.removeObject(forKey: key) }
        else { defaults.set(value, forKey: key) }
    }
}
