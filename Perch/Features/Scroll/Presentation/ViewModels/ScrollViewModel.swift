//
//  ScrollViewModel.swift
//  Perch
//
//  ponytail: a plain Bool is the whole state here — a two-case enum would just be Bool with extra typing.
//

import Observation
import Foundation

@Observable
final class ScrollViewModel {
    private(set) var isEnabled: Bool
    /// True when enabled but Accessibility permission is missing.
    private(set) var needsPermission = false

    private let manager: ScrollManager
    private let defaults = UserDefaults.standard

    init(manager: ScrollManager = ServiceLocator.shared.resolve(ScrollManager.self)) {
        self.manager = manager
        self.isEnabled = defaults.bool(forKey: Keys.Defaults.scrollReversed)
    }

    /// Re-apply the saved state at launch.
    func apply() {
        guard isEnabled else { return }
        needsPermission = !manager.start()
    }

    func toggle() {
        isEnabled.toggle()
        defaults.set(isEnabled, forKey: Keys.Defaults.scrollReversed)

        if isEnabled {
            if !Permissions.isAccessibilityTrusted {
                Permissions.requestAccessibility()
                needsPermission = true
            }
            needsPermission = !manager.start()
        } else {
            manager.stop()
            needsPermission = false
        }
    }
}
