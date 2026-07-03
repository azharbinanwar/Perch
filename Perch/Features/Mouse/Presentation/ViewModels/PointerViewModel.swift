//
//  PointerViewModel.swift
//  Perch
//
//  Pointer-acceleration control for the Mouse tab. Off by default (macOS untouched). When on,
//  applies a chosen acceleration (0 = flat 1:1). Captures the system default so it can be
//  restored when turned off or on quit.
//

import Observation
import Foundation

@Observable
final class PointerViewModel {
    private(set) var override: Bool
    private(set) var value: Double        // 0 = flat (no acceleration) … up to 20

    private let manager: PointerManager
    private let defaults = UserDefaults.standard
    private let systemDefault: Double

    init(manager: PointerManager = ServiceLocator.shared.resolve(PointerManager.self)) {
        self.manager = manager
        self.systemDefault = manager.acceleration() ?? 0.6875   // macOS default-ish
        self.override = defaults.bool(forKey: Keys.Defaults.pointerOverride)
        self.value = defaults.object(forKey: Keys.Defaults.pointerValue) as? Double ?? 0
    }

    /// Re-apply at launch.
    func apply() { push() }

    /// Restore the system default (call on quit so we don't leave the system changed).
    func restoreDefault() { manager.setAcceleration(systemDefault) }

    func setOverride(_ on: Bool) {
        override = on
        defaults.set(on, forKey: Keys.Defaults.pointerOverride)
        push()
    }

    func setValue(_ v: Double) {
        value = v
        defaults.set(v, forKey: Keys.Defaults.pointerValue)
        push()
    }

    private func push() {
        guard override else { manager.setAcceleration(systemDefault); return }
        manager.setAcceleration(value <= 0 ? -1 : value)   // 0 → disable acceleration (1:1)
    }
}
