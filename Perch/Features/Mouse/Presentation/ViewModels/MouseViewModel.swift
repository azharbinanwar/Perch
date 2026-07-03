//
//  MouseViewModel.swift
//  Perch
//
//  Drives the Mouse tab. Mouse *buttons* are auto-detected; keystroke-buttons are registered
//  once into a whitelist (one-shot capture) so normal typing never pollutes anything.
//
//  Mappings + gestures are grouped into per-app **profiles**. The UI edits one profile at a
//  time (`editingBundleID`); the capture engine always runs the profile of the *frontmost* app
//  (its own if it has one, else Default). Whitelist + detection are global (hardware, not per-app).
//

import Observation
import AppKit

@Observable
final class MouseViewModel {
    private(set) var isEnabled: Bool

    private(set) var detectingButtons = false   // auto-detect mouse buttons
    private(set) var capturingKey = false       // one-shot: register a keystroke-button
    private(set) var needsPermission = false

    private(set) var detectedButtons: [MouseTrigger] = []   // session only
    private(set) var whitelist: [MouseTrigger] = []          // persisted key chords (global)

    // Debounce (fix a worn switch that double-fires).
    private(set) var debounce: Bool
    private(set) var debounceMs: Double

    // Profiles.
    private(set) var profiles: [MouseProfile]
    private(set) var editingBundleID: String?   // nil = Default; which profile the UI edits
    private var activeBundleID: String?         // frontmost app; which profile the engine runs

    private let monitor: MouseButtonMonitor
    private let repository: MouseRepository
    private let capture: MouseCaptureManager
    private let debouncer: MouseDebounceManager
    private let defaults = UserDefaults.standard
    private var activationObserver: NSObjectProtocol?

    init(monitor: MouseButtonMonitor = ServiceLocator.shared.resolve(MouseButtonMonitor.self),
         repository: MouseRepository = ServiceLocator.shared.resolve(MouseRepository.self),
         capture: MouseCaptureManager = ServiceLocator.shared.resolve(MouseCaptureManager.self),
         debouncer: MouseDebounceManager = ServiceLocator.shared.resolve(MouseDebounceManager.self)) {
        self.monitor = monitor
        self.repository = repository
        self.capture = capture
        self.debouncer = debouncer
        self.isEnabled = defaults.object(forKey: Keys.Defaults.mouseEnabled) as? Bool ?? true
        self.whitelist = repository.loadWhitelist()
        self.debounce = defaults.bool(forKey: Keys.Defaults.mouseDebounceOn)
        self.debounceMs = defaults.object(forKey: Keys.Defaults.mouseDebounceMs) as? Double ?? 50
        self.profiles = repository.loadProfiles()
        monitor.onButton = { [weak self] in self?.handleButton($0) }
        monitor.onKey = { [weak self] code, mods in self?.handleKey(code, mods) }
    }

    deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    func apply() {
        registerActivationObserver()
        activeBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        applyActive()
        debouncer.apply(enabled: debounce, thresholdMs: debounceMs)
    }

    // MARK: - Profiles

    /// The mappings/gestures currently shown & edited in the UI.
    var mappings: [MouseMapping] { editingProfile.mappings }
    var gestures: [MouseGesture] { editingProfile.gestures }

    var appProfiles: [MouseProfile] { profiles.filter { !$0.isDefault } }
    var editingProfileName: String { editingProfile.displayName }
    var isEditingDefault: Bool { editingBundleID == nil }

    func selectProfile(_ bundleID: String?) { editingBundleID = bundleID }

    /// Add (or switch to) a profile for an app bundle id.
    func addProfile(bundleID: String) {
        if profiles.contains(where: { $0.appBundleID == bundleID }) { editingBundleID = bundleID; return }
        profiles.append(MouseProfile(appBundleID: bundleID, appName: Self.appName(for: bundleID)))
        repository.saveProfiles(profiles)
        editingBundleID = bundleID
    }

    func removeEditingProfile() {
        guard let bundleID = editingBundleID else { return }   // never remove Default
        profiles.removeAll { $0.appBundleID == bundleID }
        editingBundleID = nil
        repository.saveProfiles(profiles)
        applyActive()
    }

    private var editingProfile: MouseProfile {
        profiles.first { $0.appBundleID == editingBundleID } ?? defaultProfile
    }

    private var defaultProfile: MouseProfile {
        profiles.first { $0.isDefault } ?? MouseProfile(appBundleID: nil, appName: "Default")
    }

    private func mutateEditing(_ change: (inout MouseProfile) -> Void) {
        guard let i = profiles.firstIndex(where: { $0.appBundleID == editingBundleID }) else { return }
        change(&profiles[i])
        repository.saveProfiles(profiles)
        applyActive()
    }

    /// Push the frontmost app's profile to the engine (Default if the app has none).
    private func applyActive() {
        let active = profiles.first { $0.appBundleID == activeBundleID } ?? defaultProfile
        capture.apply(mappings: isEnabled ? active.mappings : [],
                      gestures: isEnabled ? active.gestures : [])
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

    // MARK: - Gestures (of the editing profile)

    func addGesture(for button: Int) {
        mutateEditing { p in
            guard !p.gestures.contains(where: { $0.button == button }) else { return }
            p.gestures.append(MouseGesture(button: button))
        }
    }

    func setGestureAction(_ action: MouseAction, direction: GestureDirection, for id: UUID) {
        mutateEditing { p in
            guard let i = p.gestures.firstIndex(where: { $0.id == id }) else { return }
            p.gestures[i].set(action, for: direction)
        }
    }

    func removeGesture(_ id: UUID) {
        mutateEditing { $0.gestures.removeAll { $0.id == id } }
    }

    // MARK: - Debounce

    func setDebounce(_ on: Bool) {
        debounce = on
        defaults.set(on, forKey: Keys.Defaults.mouseDebounceOn)
        debouncer.apply(enabled: on, thresholdMs: debounceMs)
    }

    func setDebounceMs(_ ms: Double) {
        debounceMs = ms
        defaults.set(ms, forKey: Keys.Defaults.mouseDebounceMs)
        debouncer.apply(enabled: debounce, thresholdMs: ms)
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        defaults.set(on, forKey: Keys.Defaults.mouseEnabled)
        applyActive()
        if !on { stopAll(); detectedButtons = [] }   // drop unset detections when turned off
    }

    // MARK: - Available triggers (to map)

    /// Detected buttons + whitelisted keys not yet mapped in this profile. Left/Right (0,1) never mappable.
    var availableTriggers: [MouseTrigger] {
        (detectedButtons + whitelist).filter { trigger in
            if case .button(let n) = trigger, n <= 1 { return false }   // Left/Right: normal click
            return !mappings.contains { $0.trigger == trigger }
        }
    }

    /// Detected extra buttons (not Left/Right) without a gesture in this profile.
    var availableGestureButtons: [Int] {
        let gestured = Set(gestures.map(\.button))
        return detectedButtons.compactMap { if case .button(let n) = $0 { return n } else { return nil } }
            .filter { $0 > 1 && !gestured.contains($0) }
    }

    // MARK: - Button detection

    func toggleButtonDetect() { detectingButtons ? stopButtonDetect() : startButtonDetect() }

    private func startButtonDetect() {
        capturingKey = false
        ensureTap()
        detectingButtons = !needsPermission
    }
    func stopButtonDetect() { detectingButtons = false; stopTapIfIdle() }

    private func handleButton(_ number: Int) {
        guard detectingButtons else { return }   // detect everything so you can see all buttons
        let trigger = MouseTrigger.button(number)
        if !detectedButtons.contains(trigger) { detectedButtons.append(trigger) }
    }

    /// Clear detected buttons that were never mapped in this profile.
    func clearDetected() {
        detectedButtons.removeAll { trigger in !mappings.contains { $0.trigger == trigger } }
    }

    // MARK: - Keystroke whitelist (one-shot capture, global)

    func startKeyCapture() {
        detectingButtons = false
        ensureTap()
        capturingKey = !needsPermission
    }
    func cancelKeyCapture() { capturingKey = false; stopTapIfIdle() }

    private func handleKey(_ code: Int, _ modifiers: UInt64) {
        guard capturingKey else { return }   // outside capture, all typing is ignored
        let trigger = MouseTrigger.key(code: code, modifiers: modifiers)
        if !whitelist.contains(trigger) {
            whitelist.append(trigger)
            repository.saveWhitelist(whitelist)
        }
        capturingKey = false
        stopTapIfIdle()
    }

    func removeWhitelisted(_ trigger: MouseTrigger) {
        whitelist.removeAll { $0 == trigger }
        repository.saveWhitelist(whitelist)
    }

    // MARK: - Mappings (of the editing profile)

    func addMapping(for trigger: MouseTrigger) {
        mutateEditing { p in
            guard !p.mappings.contains(where: { $0.trigger == trigger }) else { return }
            p.mappings.append(MouseMapping(trigger: trigger, action: Self.suggestedAction(for: trigger)))
        }
    }

    func setAction(_ action: MouseAction, for id: UUID) {
        setAction(action, phase: .single, for: id)
    }

    func setAction(_ action: MouseAction, phase: ClickPhase, for id: UUID) {
        mutateEditing { p in
            guard let i = p.mappings.firstIndex(where: { $0.id == id }) else { return }
            p.mappings[i].setAction(action, for: phase)
        }
    }

    func removeMapping(_ id: UUID) {
        mutateEditing { $0.mappings.removeAll { $0.id == id } }
    }

    /// Left/Right/Middle default to their normal click (pass-through); side buttons to back/forward.
    private static func suggestedAction(for trigger: MouseTrigger) -> MouseAction {
        guard case .button(let n) = trigger else { return .disabled }
        switch n {
        case 0, 1, 2: return MouseAction(kind: .passThrough)   // stays a normal click until assigned
        case 3:       return MouseAction(kind: .back)
        case 4:       return MouseAction(kind: .forward)
        default:      return .disabled
        }
    }

    // MARK: - Tap lifecycle

    private func ensureTap() {
        if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
        needsPermission = !monitor.start()
    }
    private func stopTapIfIdle() { if !detectingButtons && !capturingKey { monitor.stop() } }
    private func stopAll() { detectingButtons = false; capturingKey = false; monitor.stop() }
}
