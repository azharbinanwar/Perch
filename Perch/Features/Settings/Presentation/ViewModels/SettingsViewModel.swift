//
//  SettingsViewModel.swift
//  Perch
//

import AppKit
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

    // Global open-clipboard hotkey.
    private(set) var hotKeyCode: UInt32
    private(set) var hotKeyModifiers: NSEvent.ModifierFlags
    private(set) var hotKeyLabel: String

    var hotKeyDisplay: String { HotKeyRecorder.symbols(hotKeyModifiers) + hotKeyLabel }

    private let defaults = UserDefaults.standard
    private let repository: SettingsRepository

    /// Allowed menu-peek counts (kept small so the dropdown never runs off-screen).
    static let menuCountOptions = [5, 10, 15]

    init(repository: SettingsRepository = ServiceLocator.shared.resolve(SettingsRepository.self)) {
        self.repository = repository
        self.hotKeyCode = UInt32(defaults.object(forKey: Keys.Defaults.hotKeyCode) as? Int ?? 9)   // V
        let rawMods = defaults.object(forKey: Keys.Defaults.hotKeyModifiers) as? UInt
            ?? NSEvent.ModifierFlags([.command, .shift]).rawValue
        self.hotKeyModifiers = NSEvent.ModifierFlags(rawValue: rawMods)
        self.hotKeyLabel = defaults.string(forKey: Keys.Defaults.hotKeyLabel) ?? "V"

        var loaded = repository.load()
        // Migrate any legacy/out-of-range menu count to a valid preset.
        if !Self.menuCountOptions.contains(loaded.menuItemCount) {
            loaded.menuItemCount = 10
            repository.save(loaded)
        }
        self.settings = loaded   // no didSet on init — we don't want to re-save on load
    }

    func setHotKey(code: UInt32, modifiers: NSEvent.ModifierFlags, label: String) {
        hotKeyCode = code
        hotKeyModifiers = modifiers
        hotKeyLabel = label
        defaults.set(Int(code), forKey: Keys.Defaults.hotKeyCode)
        defaults.set(modifiers.rawValue, forKey: Keys.Defaults.hotKeyModifiers)
        defaults.set(label, forKey: Keys.Defaults.hotKeyLabel)
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
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
