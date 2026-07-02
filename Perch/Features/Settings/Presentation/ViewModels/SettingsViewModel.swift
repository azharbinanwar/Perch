//
//  SettingsViewModel.swift
//  Perch
//

import Observation
import ServiceManagement

@Observable
final class SettingsViewModel {
    /// Views bind directly to this; every change persists and syncs the login item.
    var settings: AppSettings {
        didSet {
            repository.save(settings)
            if settings.openAtLogin != oldValue.openAtLogin { applyLoginItem() }
        }
    }

    private let repository: SettingsRepository

    /// Allowed menu-peek counts (kept small so the dropdown never runs off-screen).
    static let menuCountOptions = [5, 10, 15]

    init(repository: SettingsRepository = ServiceLocator.shared.resolve(SettingsRepository.self)) {
        self.repository = repository
        var loaded = repository.load()
        // Migrate any legacy/out-of-range menu count to a valid preset.
        if !Self.menuCountOptions.contains(loaded.menuItemCount) {
            loaded.menuItemCount = 10
            repository.save(loaded)
        }
        self.settings = loaded   // no didSet on init — we don't want to re-save on load
    }

    /// Register/unregister the app as a login item to match the saved preference.
    func applyLoginItem() {
        do {
            if settings.openAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // ponytail: login-item errors are non-fatal — the toggle just reflects intent; user can retry.
        }
    }
}
