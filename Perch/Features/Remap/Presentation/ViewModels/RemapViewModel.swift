//
//  RemapViewModel.swift
//  Perch
//
//  Drives the Keys tab. Rules are grouped into per-app **profiles**: the UI edits one profile
//  (`editingBundleID`); the engine runs the profile of the *frontmost* app (its own, else
//  Default). New rules are built by recording two combos (KeyChordRecorder swallows the keys).
//

import Observation
import AppKit

enum RemapField { case input, output }

@Observable
final class RemapViewModel {
    private(set) var isEnabled: Bool
    private(set) var needsPermission = false

    // Profiles.
    private(set) var profiles: [RemapProfile]
    private(set) var editingBundleID: String?   // nil = Default; which profile the UI edits
    private var activeBundleID: String?         // frontmost app; which profile the engine runs

    // Draft while adding/editing a mapping.
    private(set) var draftInput: KeyCombo?
    private(set) var draftOutput: Action?
    private(set) var recording: RemapField?
    private(set) var editingRuleID: UUID?   // non-nil = editing an existing rule in place

    private let repository: RemapRepository
    private let manager: RemapManager
    private let recorder = KeyChordRecorder()
    private let defaults = UserDefaults.standard
    private var activationObserver: NSObjectProtocol?

    init(repository: RemapRepository = ServiceLocator.shared.resolve(RemapRepository.self),
         manager: RemapManager = ServiceLocator.shared.resolve(RemapManager.self)) {
        self.repository = repository
        self.manager = manager
        self.isEnabled = defaults.bool(forKey: Keys.Defaults.remapEnabled)
        self.profiles = repository.loadProfiles()
    }

    deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    /// Re-apply saved state at launch.
    func apply() {
        registerActivationObserver()
        activeBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        applyActive()
        guard isEnabled else { return }
        needsPermission = !manager.start()
    }

    // MARK: - Profiles

    /// The rules currently shown & edited in the UI.
    var rules: [RemapRule] { editingProfile.rules }

    var appProfiles: [RemapProfile] { profiles.filter { !$0.isDefault } }
    var editingProfileName: String { editingProfile.displayName }
    var isEditingDefault: Bool { editingBundleID == nil }

    func selectProfile(_ bundleID: String?) { editingBundleID = bundleID }

    /// Add (or switch to) a profile for an app — starts as a copy of Default's rules.
    func addProfile(bundleID: String) {
        if profiles.contains(where: { $0.appBundleID == bundleID }) { editingBundleID = bundleID; return }
        profiles.append(RemapProfile(appBundleID: bundleID, appName: Self.appName(for: bundleID), rules: defaultProfile.rules))
        repository.saveProfiles(profiles)
        editingBundleID = bundleID
    }

    func removeEditingProfile() {
        guard let bundleID = editingBundleID else { return }
        profiles.removeAll { $0.appBundleID == bundleID }
        editingBundleID = nil
        repository.saveProfiles(profiles)
        applyActive()
    }

    private var editingProfile: RemapProfile {
        profiles.first { $0.appBundleID == editingBundleID } ?? defaultProfile
    }

    private var defaultProfile: RemapProfile {
        profiles.first { $0.isDefault } ?? RemapProfile(appBundleID: nil, appName: "Default")
    }

    private func mutateEditing(_ change: (inout RemapProfile) -> Void) {
        guard let i = profiles.firstIndex(where: { $0.appBundleID == editingBundleID }) else { return }
        change(&profiles[i])
        repository.saveProfiles(profiles)
        applyActive()
    }

    /// Push the frontmost app's rules to the engine (Default if the app has none).
    private func applyActive() {
        let active = profiles.first { $0.appBundleID == activeBundleID } ?? defaultProfile
        manager.rules = isEnabled ? active.rules : []
    }

    private func registerActivationObserver() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.activeBundleID = app?.bundleIdentifier
            self.applyActive()
        }
    }

    private static func appName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    // MARK: - Enable / rules

    func toggleEnabled() {
        isEnabled.toggle()
        defaults.set(isEnabled, forKey: Keys.Defaults.remapEnabled)
        // Keep the event tap alive once started; disabling just empties the rules (passthrough) so
        // re-enabling never has to recreate a tap — which macOS doesn't always re-establish cleanly.
        if isEnabled {
            if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
            needsPermission = !manager.start()   // idempotent — no-op if already running
        } else {
            needsPermission = false
        }
        applyActive()
    }

    func toggleRule(_ rule: RemapRule) {
        mutateEditing { p in
            guard let i = p.rules.firstIndex(where: { $0.id == rule.id }) else { return }
            p.rules[i].isEnabled.toggle()
        }
    }

    func removeRule(_ rule: RemapRule) {
        mutateEditing { $0.rules.removeAll { $0.id == rule.id } }
    }

    // MARK: - Recording a new mapping

    func record(_ field: RemapField) {
        if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
        recording = field
        recorder.onCapture = { [weak self] code, mods in
            guard let self else { return }
            if self.recording == .input {
                self.draftInput = KeyCombo(keyCode: code, modifiers: mods)
            } else {
                self.draftOutput = Action(kind: .customKeystroke, keyCode: code, modifiers: mods)
            }
            self.recording = nil
            self.recorder.stop()
        }
        _ = recorder.start()
    }

    /// The "Pick" path — output chosen from the action catalogue (target already resolved).
    func setOutputAction(_ action: Action) { draftOutput = action }

    /// Load an existing rule into the draft to edit it in place.
    func beginEdit(_ rule: RemapRule) {
        draftInput = rule.input
        draftOutput = rule.output
        editingRuleID = rule.id
        cancelRecording()
    }

    func cancelRecording() {
        recording = nil
        recorder.stop()
    }

    /// True when both sides are captured and the input isn't already mapped by a *different* rule.
    var canAddDraft: Bool {
        guard let input = draftInput else { return false }
        return draftOutput != nil && !rules.contains { $0.input == input && $0.id != editingRuleID }
    }

    /// Save the draft — updates the edited rule in place, or appends a new one.
    func addDraft() {
        guard let input = draftInput, let output = draftOutput, canAddDraft else { return }
        if let id = editingRuleID {
            mutateEditing { p in
                guard let i = p.rules.firstIndex(where: { $0.id == id }) else { return }
                p.rules[i].input = input
                p.rules[i].output = output
            }
        } else {
            mutateEditing { $0.rules.append(RemapRule(input: input, output: output)) }
        }
        clearDraft()
    }

    func clearDraft() {
        draftInput = nil
        draftOutput = nil
        editingRuleID = nil
        cancelRecording()
    }
}
