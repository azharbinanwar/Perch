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

    private(set) var scanning = false            // scan mode: press buttons, they light up on the mouse
    private(set) var needsPermission = false

    private(set) var detectedButtons: [MouseTrigger] = []   // scanned physical extra buttons (persisted)
    private(set) var whitelist: [MouseTrigger] = []          // persisted key chords (global)
    private(set) var lastAdded: MouseTrigger?               // last button added (for auto-select)
    private(set) var addCount = 0                            // bumps on every add (even a re-add)

    // Debounce (fix a worn switch that double-fires).
    private(set) var debounce: Bool
    private(set) var debounceMs: Double

    // Swap primary/secondary buttons (left-handed).
    private(set) var swapButtons: Bool

    // Profiles.
    private(set) var profiles: [MouseProfile]
    private(set) var editingBundleID: String?   // nil = Default; which profile the UI edits
    private var activeBundleID: String?         // frontmost app; which profile the engine runs

    // Connected mice (for the readout / no-mouse empty state).
    private(set) var devices: [MouseDevice] = []
    var hasMouse: Bool { !devices.isEmpty }
    var deviceSubtitle: String {
        switch devices.count {
        case 0:  return "No mouse connected"
        case 1:  return devices[0].summary
        default: return "\(devices.count) mice connected — mappings apply to all"
        }
    }

    private let monitor: MouseButtonMonitor
    private let repository: MouseRepository
    private let capture: MouseCaptureManager
    private let debouncer: MouseDebounceManager
    private let deviceMonitor: MouseDeviceMonitor
    private let keyRecorder = KeyChordRecorder()   // swallows the key so capture doesn't fire it
    private let defaults = UserDefaults.standard
    private var activationObserver: NSObjectProtocol?
    private var idleStop: DispatchWorkItem?        // auto-ends a scan after a few idle seconds

    init(monitor: MouseButtonMonitor = ServiceLocator.shared.resolve(MouseButtonMonitor.self),
         repository: MouseRepository = ServiceLocator.shared.resolve(MouseRepository.self),
         capture: MouseCaptureManager = ServiceLocator.shared.resolve(MouseCaptureManager.self),
         debouncer: MouseDebounceManager = ServiceLocator.shared.resolve(MouseDebounceManager.self),
         deviceMonitor: MouseDeviceMonitor = ServiceLocator.shared.resolve(MouseDeviceMonitor.self)) {
        self.monitor = monitor
        self.repository = repository
        self.capture = capture
        self.debouncer = debouncer
        self.deviceMonitor = deviceMonitor
        self.isEnabled = defaults.object(forKey: Keys.Defaults.mouseEnabled) as? Bool ?? true
        self.whitelist = repository.loadWhitelist()
        self.detectedButtons = repository.loadDetected()
        self.debounce = defaults.bool(forKey: Keys.Defaults.mouseDebounceOn)
        self.debounceMs = defaults.object(forKey: Keys.Defaults.mouseDebounceMs) as? Double ?? 50
        self.swapButtons = defaults.bool(forKey: Keys.Defaults.mouseSwap)
        self.profiles = repository.loadProfiles()
        monitor.onButton = { [weak self] in self?.handleAddButton($0) }
        deviceMonitor.onChange = { [weak self] in self?.devices = $0 }
    }

    deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    func apply() {
        registerActivationObserver()
        deviceMonitor.start()
        activeBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        applyActive()
        debouncer.apply(enabled: debounce, thresholdMs: debounceMs)
    }

    /// Re-read from storage and re-apply (used after Import).
    func reload() {
        isEnabled = defaults.object(forKey: Keys.Defaults.mouseEnabled) as? Bool ?? true
        whitelist = repository.loadWhitelist()
        detectedButtons = repository.loadDetected()
        debounce = defaults.bool(forKey: Keys.Defaults.mouseDebounceOn)
        debounceMs = defaults.object(forKey: Keys.Defaults.mouseDebounceMs) as? Double ?? 50
        swapButtons = defaults.bool(forKey: Keys.Defaults.mouseSwap)
        profiles = repository.loadProfiles()
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

    /// Add (or switch to) a profile for an app bundle id. New profiles start as a copy of
    /// Default's actions, so every button carries over and the user only tweaks the differences.
    func addProfile(bundleID: String) {
        if profiles.contains(where: { $0.appBundleID == bundleID }) { editingBundleID = bundleID; return }
        let base = defaultProfile
        profiles.append(MouseProfile(appBundleID: bundleID, appName: Self.appName(for: bundleID),
                                     mappings: base.mappings, gestures: base.gestures))
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
        capture.swapEnabled = isEnabled && swapButtons
        if isEnabled { capture.start() }   // idempotent; keeps the tap alive & retries if permission was just granted
    }

    func setSwapButtons(_ on: Bool) {
        swapButtons = on
        defaults.set(on, forKey: Keys.Defaults.mouseSwap)
        applyActive()
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

    func setGestureAction(_ action: Action, direction: GestureDirection, for id: UUID) {
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
        if on, !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
        applyActive()          // starts/keeps the tap alive when on; empties mappings (passthrough) when off
        if !on { stopScan() }
    }

    // MARK: - Scan (press buttons; they light up on the mouse)

    /// Enter scan mode — mouse buttons (listen-only) and keystroke buttons (swallowed so they
    /// don't fire) both light up their slot. Stays on until Done or a few idle seconds pass.
    func startScan() {
        if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }
        let mouseOK = monitor.start()
        keyRecorder.onCapture = { [weak self] code, mods in self?.handleAddKey(code, mods) }
        let keyOK = keyRecorder.start()
        needsPermission = !(mouseOK && keyOK)
        scanning = mouseOK && keyOK
        if scanning { armIdleStop() } else { monitor.stop(); keyRecorder.stop() }
    }

    func stopScan() {
        scanning = false
        idleStop?.cancel(); idleStop = nil
        monitor.stop()
        keyRecorder.stop()
    }

    private func handleAddButton(_ number: Int) {
        guard scanning else { return }
        let trigger = MouseTrigger.button(number)
        if number >= 3, !detectedButtons.contains(trigger) {
            detectedButtons.append(trigger)
            repository.saveDetected(detectedButtons)
        }
        registerAdded(trigger)
    }

    private func handleAddKey(_ code: Int, _ modifiers: UInt64) {
        guard scanning else { return }
        let trigger = MouseTrigger.key(code: code, modifiers: modifiers)
        if !whitelist.contains(trigger) {
            whitelist.append(trigger)
            repository.saveWhitelist(whitelist)
        }
        registerAdded(trigger)
    }

    private func registerAdded(_ trigger: MouseTrigger) {
        lastAdded = trigger
        addCount += 1
        armIdleStop()   // keep scanning; reset the idle timeout
    }

    private func armIdleStop() {
        idleStop?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.stopScan() }
        idleStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    func removeWhitelisted(_ trigger: MouseTrigger) {
        whitelist.removeAll { $0 == trigger }
        repository.saveWhitelist(whitelist)
    }

    // MARK: - Mappings (of the editing profile)

    func setAction(_ action: Action, phase: ClickPhase, for id: UUID) {
        mutateEditing { p in
            guard let i = p.mappings.firstIndex(where: { $0.id == id }) else { return }
            p.mappings[i].setAction(action, for: phase)
        }
    }

    func removeMapping(_ id: UUID) {
        mutateEditing { $0.mappings.removeAll { $0.id == id } }
    }

    // MARK: - Trigger-based access (for the diagram UI: read/set by trigger, find-or-create)

    func mapping(for trigger: MouseTrigger) -> MouseMapping? {
        mappings.first { $0.trigger == trigger }
    }

    func action(for trigger: MouseTrigger, phase: ClickPhase) -> Action {
        mapping(for: trigger)?.action(for: phase) ?? .disabled
    }

    func setAction(_ action: Action, for trigger: MouseTrigger, phase: ClickPhase) {
        mutateEditing { p in
            if let i = p.mappings.firstIndex(where: { $0.trigger == trigger }) {
                p.mappings[i].setAction(action, for: phase)
            } else {
                var m = MouseMapping(trigger: trigger, action: .disabled)
                m.setAction(action, for: phase)
                p.mappings.append(m)
            }
        }
    }

    func gestureAction(for button: Int, direction: GestureDirection) -> Action {
        gestures.first { $0.button == button }?.action(for: direction) ?? .disabled
    }

    func setGestureAction(_ action: Action, for button: Int, direction: GestureDirection) {
        mutateEditing { p in
            if let i = p.gestures.firstIndex(where: { $0.button == button }) {
                p.gestures[i].set(action, for: direction)
            } else {
                var g = MouseGesture(button: button)
                g.set(action, for: direction)
                p.gestures.append(g)
            }
        }
    }

}
