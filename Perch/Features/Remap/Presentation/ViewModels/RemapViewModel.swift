//
//  RemapViewModel.swift
//  Perch
//

import Observation
import Foundation

@Observable
final class RemapViewModel {
    private(set) var rules: [RemapRule]
    private(set) var isEnabled: Bool
    private(set) var needsPermission = false

    private let repository: RemapRepository
    private let manager: RemapManager
    private let defaults = UserDefaults.standard

    init(repository: RemapRepository = ServiceLocator.shared.resolve(RemapRepository.self),
         manager: RemapManager = ServiceLocator.shared.resolve(RemapManager.self)) {
        self.repository = repository
        self.manager = manager
        self.rules = repository.load()
        self.isEnabled = defaults.bool(forKey: Keys.Defaults.remapEnabled)
        manager.rules = rules
    }

    /// Re-apply saved state at launch.
    func apply() {
        guard isEnabled else { return }
        needsPermission = !manager.start()
    }

    func toggleEnabled() {
        isEnabled.toggle()
        defaults.set(isEnabled, forKey: Keys.Defaults.remapEnabled)
        if isEnabled {
            if !Permissions.isAccessibilityTrusted {
                Permissions.requestAccessibility()
            }
            needsPermission = !manager.start()
        } else {
            manager.stop()
            needsPermission = false
        }
    }

    func toggleRule(_ rule: RemapRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index].isEnabled.toggle()
        persist()
    }

    func removeRule(_ rule: RemapRule) {
        rules.removeAll { $0.id == rule.id }
        persist()
    }

    func addRule(keyChar: String) {
        let char = keyChar.lowercased()
        guard !char.isEmpty, !rules.contains(where: { $0.keyChar == char }) else { return }
        rules.append(RemapRule(keyChar: char))
        persist()
    }

    private func persist() {
        repository.save(rules)
        manager.rules = rules
    }
}
