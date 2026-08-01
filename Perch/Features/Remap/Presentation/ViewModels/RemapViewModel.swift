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
    private var draftViaHyper = false            // input recorded with the Hyper key held
    private(set) var draftOutput: Action?
    var draftSmart = true                        // smart detect for the drafted rule (modified inputs)
    private(set) var recording: RemapField?
    private(set) var editingRuleID: UUID?   // non-nil = editing an existing rule in place

    // Hyper Key + Double-tap — PER-PROFILE now; the UI reads the editing profile's values.
    var hyperEnabled: Bool { editingProfile.hyper.enabled }
    var hyperTap: HyperKeyManager.TapAction { .init(rawValue: editingProfile.hyper.tap) ?? .escape }
    var hyperDoubleTap: HyperKeyManager.TapAction { .init(rawValue: editingProfile.hyper.doubleTap) ?? .capsLock }
    var hyperShift: Bool { editingProfile.hyper.shift }
    var doubleTap: DoubleTapConfig { editingProfile.doubleTap }

    private let repository: RemapRepository
    private let manager: RemapManager
    private let hyper: HyperKeyManager
    private let doubleTapManager: DoubleTapManager
    private let recorder = KeyChordRecorder()
    private let defaults = UserDefaults.standard
    private var activationObserver: NSObjectProtocol?

    init(repository: RemapRepository = ServiceLocator.shared.resolve(RemapRepository.self),
         manager: RemapManager = ServiceLocator.shared.resolve(RemapManager.self),
         hyper: HyperKeyManager = ServiceLocator.shared.resolve(HyperKeyManager.self),
         doubleTapManager: DoubleTapManager = ServiceLocator.shared.resolve(DoubleTapManager.self)) {
        self.repository = repository
        self.manager = manager
        self.hyper = hyper
        self.doubleTapManager = doubleTapManager
        self.isEnabled = defaults.bool(forKey: Keys.Defaults.remapEnabled)
        self.profiles = repository.loadProfiles()   // migrates old global hyper/double-tap in

        // Let the recorder treat a held hyper key like a modifier (nil = feature off → unchanged).
        recorder.hyperFlags = { [weak self] in
            guard let self, self.hyperEnabled else { return nil }
            return self.hyper.isHyperHeld ? self.hyper.activeFlags : CGEventFlags()
        }
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

    /// Re-read from storage and re-apply (used after Import).
    func reload() {
        isEnabled = defaults.bool(forKey: Keys.Defaults.remapEnabled)
        profiles = repository.loadProfiles()
        if isEnabled { needsPermission = !manager.start() }
        applyActive()
    }

    // MARK: - Double-tap modifiers (per-profile)

    func setDoubleTapEnabled(_ on: Bool) {
        mutateEditing { $0.doubleTap.enabled = on }
    }

    /// nil action clears the modifier back to "Do Nothing".
    func setDoubleTapAction(_ action: Action?, for modifier: String) {
        mutateEditing { $0.doubleTap.actions[modifier] = action }
    }

    // MARK: - Hyper Key (per-profile)

    func setHyperEnabled(_ on: Bool) {
        mutateEditing { $0.hyper.enabled = on }
    }

    func setHyperTap(_ action: HyperKeyManager.TapAction) {
        mutateEditing { $0.hyper.tap = action.rawValue }
    }

    func setHyperDoubleTap(_ action: HyperKeyManager.TapAction) {
        mutateEditing { $0.hyper.doubleTap = action.rawValue }
    }

    func setHyperShift(_ on: Bool) {
        let oldMask = hyperModifierMask(includeShift: hyperShift)
        let newMask = hyperModifierMask(includeShift: on)
        // Migrate THIS profile's Hyper-recorded rules to the new combo so nothing stops matching.
        mutateEditing { p in
            p.hyper.shift = on
            for j in p.rules.indices where p.rules[j].isHyperKey {
                let mods = p.rules[j].input.modifiers
                p.rules[j].input.modifiers = (mods & ~oldMask) | newMask
            }
        }
    }

    private func hyperModifierMask(includeShift: Bool) -> UInt64 {
        let flags: CGEventFlags = includeShift
            ? [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            : [.maskCommand, .maskAlternate, .maskControl]
        return flags.rawValue
    }

    /// On app quit: remove the system remap so Caps Lock is never left dead.
    func hyperCleanupForQuit() { hyper.cleanupForQuit() }

    // MARK: - Profiles

    /// The rules currently shown & edited in the UI.
    var rules: [RemapRule] { editingProfile.rules }

    var appProfiles: [RemapProfile] { profiles.filter { !$0.isDefault } }
    var editingProfileName: String { editingProfile.displayName }
    var isEditingDefault: Bool { editingBundleID == nil }

    func selectProfile(_ bundleID: String?) { editingBundleID = bundleID }

    /// Add (or switch to) a profile for an app — starts as a full copy of Default
    /// (rules, Hyper Key AND Double-Tap), then each is editable per app.
    func addProfile(bundleID: String) {
        if profiles.contains(where: { $0.appBundleID == bundleID }) { editingBundleID = bundleID; return }
        let base = defaultProfile
        profiles.append(RemapProfile(appBundleID: bundleID, appName: Self.appName(for: bundleID),
                                     rules: base.rules, hyper: base.hyper, doubleTap: base.doubleTap))
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

    /// Push the frontmost app's profile to ALL engines (Default if the app has none):
    /// rules + Hyper Key + Double-Tap. Master switch off beats everything.
    private func applyActive() {
        // Push the module master into every engine's cheap hot-path gate.
        manager.keysModuleEnabled = isEnabled
        hyper.keysModuleEnabled = isEnabled
        doubleTapManager.keysModuleEnabled = isEnabled

        let active = profiles.first { $0.appBundleID == activeBundleID } ?? defaultProfile
        manager.rules = isEnabled ? active.rules : []

        // Hyper: the hidutil remap is installed while ANY profile wants Hyper (installing it
        // is a process spawn — too heavy for every app switch). The frontmost profile then
        // gates behavior: inactive → the key acts as real Caps Lock again.
        hyper.tapAction = .init(rawValue: active.hyper.tap) ?? .escape
        hyper.doubleTapAction = .init(rawValue: active.hyper.doubleTap) ?? .capsLock
        hyper.includeShift = active.hyper.shift
        hyper.perAppActive = isEnabled && active.hyper.enabled
        let anyHyper = isEnabled && profiles.contains { $0.hyper.enabled }
        if anyHyper { hyper.enable() } else { hyper.disable() }

        doubleTapManager.config = active.doubleTap
        doubleTapManager.isActive = isEnabled && active.doubleTap.enabled
        if doubleTapManager.isActive { doubleTapManager.start() }
    }

    private func registerActivationObserver() {
        guard activationObserver == nil else { return }
        // Tell the permission service how to switch this module off (called when a check finds
        // Accessibility missing). toggleEnabled off also tears down Hyper (undoes the Caps remap).
        AccessibilityService.shared.registerGate { [weak self] in
            guard let self, self.isEnabled else { return }
            self.toggleEnabled()
        }
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
            if !AccessibilityService.shared.trusted { AccessibilityService.shared.request() }
            needsPermission = !manager.start()   // idempotent — no-op if already running
        } else {
            needsPermission = false
        }
        applyActive()   // master off also disables Hyper (removes the system Caps remap) + double-tap
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
        if !AccessibilityService.shared.trusted { AccessibilityService.shared.request() }
        recording = field
        recorder.onCapture = { [weak self] code, mods in
            guard let self else { return }
            if self.recording == .input {
                self.draftInput = KeyCombo(keyCode: code, modifiers: mods)
                self.draftViaHyper = self.recorder.lastCaptureViaHyper
                // Recording IS the detector: hardware burst → smart on, typed by hand → off.
                self.draftSmart = self.recorder.lastCaptureWasHardware
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
        draftViaHyper = rule.isHyperKey
        draftOutput = rule.output
        draftSmart = rule.smartDetect
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
                p.rules[i].isHyperKey = self.draftViaHyper
                p.rules[i].smartDetect = self.draftSmart
            }
        } else {
            mutateEditing { $0.rules.append(RemapRule(input: input, output: output,
                                                      isHyperKey: draftViaHyper, smartDetect: draftSmart)) }
        }
        clearDraft()
    }

    func clearDraft() {
        draftInput = nil
        draftViaHyper = false
        draftOutput = nil
        draftSmart = true
        editingRuleID = nil
        cancelRecording()
    }
}
