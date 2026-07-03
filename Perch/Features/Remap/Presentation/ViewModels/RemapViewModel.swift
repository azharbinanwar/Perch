//
//  RemapViewModel.swift
//  Perch
//
//  Drives the Keys tab. General remapper: each rule is an input combo → output combo.
//  New rules are built by recording the two combos (KeyChordRecorder swallows the keys).
//

import Observation
import Foundation

enum RemapField { case input, output }

@Observable
final class RemapViewModel {
    private(set) var rules: [RemapRule]
    private(set) var isEnabled: Bool
    private(set) var needsPermission = false

    // Draft while adding a mapping.
    private(set) var draftInput: KeyCombo?
    private(set) var draftOutput: KeyCombo?
    private(set) var recording: RemapField?

    private let repository: RemapRepository
    private let manager: RemapManager
    private let recorder = KeyChordRecorder()
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
            if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
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

    // MARK: - Recording a new mapping

    func record(_ field: RemapField) {
        if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
        recording = field
        recorder.onCapture = { [weak self] code, mods in
            guard let self else { return }
            let combo = KeyCombo(keyCode: code, modifiers: mods)
            if self.recording == .input { self.draftInput = combo } else { self.draftOutput = combo }
            self.recording = nil
            self.recorder.stop()
        }
        _ = recorder.start()
    }

    func cancelRecording() {
        recording = nil
        recorder.stop()
    }

    /// True when both sides are captured and the input isn't already mapped.
    var canAddDraft: Bool {
        guard let input = draftInput else { return false }
        return draftOutput != nil && !rules.contains { $0.input == input }
    }

    func addDraft() {
        guard let input = draftInput, let output = draftOutput, canAddDraft else { return }
        rules.append(RemapRule(input: input, output: output))
        clearDraft()
        persist()
    }

    func clearDraft() {
        draftInput = nil
        draftOutput = nil
        cancelRecording()
    }

    private func persist() {
        repository.save(rules)
        manager.rules = rules
    }
}
