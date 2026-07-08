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
    private(set) var masterEnabled: Bool   // top-level master — off = whole Mouse tab paused
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
    private let scrollManager: ScrollManager
    private let autoScrollManager: AutoScrollManager
    private let pointerManager: PointerManager
    private let pointerSystemDefault: Double       // captured before we ever touch acceleration
    private let keyRecorder = KeyChordRecorder()   // swallows the key so capture doesn't fire it
    private let defaults = UserDefaults.standard
    private var activationObserver: NSObjectProtocol?
    private var idleStop: DispatchWorkItem?        // auto-ends a scan after a few idle seconds

    init(monitor: MouseButtonMonitor = ServiceLocator.shared.resolve(MouseButtonMonitor.self),
         repository: MouseRepository = ServiceLocator.shared.resolve(MouseRepository.self),
         capture: MouseCaptureManager = ServiceLocator.shared.resolve(MouseCaptureManager.self),
         debouncer: MouseDebounceManager = ServiceLocator.shared.resolve(MouseDebounceManager.self),
         deviceMonitor: MouseDeviceMonitor = ServiceLocator.shared.resolve(MouseDeviceMonitor.self),
         scrollManager: ScrollManager = ServiceLocator.shared.resolve(ScrollManager.self),
         autoScrollManager: AutoScrollManager = ServiceLocator.shared.resolve(AutoScrollManager.self),
         pointerManager: PointerManager = ServiceLocator.shared.resolve(PointerManager.self)) {
        self.monitor = monitor
        self.repository = repository
        self.capture = capture
        self.debouncer = debouncer
        self.deviceMonitor = deviceMonitor
        self.scrollManager = scrollManager
        self.autoScrollManager = autoScrollManager
        self.pointerManager = pointerManager
        self.pointerSystemDefault = pointerManager.acceleration() ?? 0.6875   // macOS default-ish
        self.masterEnabled = defaults.object(forKey: Keys.Defaults.mouseMasterOn) as? Bool ?? true
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
        masterEnabled = defaults.object(forKey: Keys.Defaults.mouseMasterOn) as? Bool ?? true
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

    /// Add (or switch to) a profile for an app bundle id. New profiles start as a FULL copy of
    /// Default — mappings, gestures, scroll and pointer — so the user only tweaks differences.
    func addProfile(bundleID: String) {
        if profiles.contains(where: { $0.appBundleID == bundleID }) { editingBundleID = bundleID; return }
        let base = defaultProfile
        profiles.append(MouseProfile(appBundleID: bundleID, appName: Self.appName(for: bundleID),
                                     mappings: base.mappings, gestures: base.gestures,
                                     scroll: base.scroll, pointer: base.pointer,
                                     layer: base.layer))
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

    /// Push the frontmost app's profile to ALL engines (Default if the app has none):
    /// buttons + gestures + the button layer, and its scroll/pointer settings.
    private func applyActive() {
        // Push the module master into every engine's cheap hot-path gate.
        capture.mouseModuleEnabled = masterEnabled
        scrollManager.mouseModuleEnabled = masterEnabled
        autoScrollManager.mouseModuleEnabled = masterEnabled
        debouncer.mouseModuleEnabled = masterEnabled
        // Master off → pause EVERY mouse engine (buttons, scroll, auto-scroll, pointer).
        guard masterEnabled else {
            capture.apply(mappings: [], gestures: [], layers: [:])
            capture.swapEnabled = false
            capture.stop()
            scrollManager.stop()
            _ = autoScrollManager.apply(default: AutoScrollConfig(on: false, button: 0, speed: 1), perApp: [:])
            restorePointerDefault()
            return
        }
        let active = profiles.first { $0.appBundleID == activeBundleID } ?? defaultProfile
        // Each shift key ships its OWN combo dict. A hold key with zero live combos is
        // skipped entirely so it never swallows the button for nothing.
        var layers: [Int: [MouseMapping]] = [:]
        if isEnabled, active.layer.enabled {
            for holdLayer in active.layer.layers {
                guard case .button(let n) = holdLayer.hold else { continue }
                let live = holdLayer.mappings.filter { m in
                    ClickPhase.allCases.contains { m.action(for: $0).kind != .disabled }
                }
                if !live.isEmpty { layers[n] = live }
            }
        }
        capture.apply(mappings: isEnabled ? active.mappings : [],
                      gestures: isEnabled ? active.gestures : [],
                      layers: layers)
        capture.swapEnabled = isEnabled && swapButtons
        if isEnabled { capture.start() }   // idempotent; keeps the tap alive & retries if permission was just granted

        // Scroll AND auto-scroll follow the app under the CURSOR — hand the engines every
        // profile's config. Pointer follows the frontmost app (it's screen-wide, focus-bound).
        let perAppScroll = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in
            p.appBundleID.map { ($0, ScrollConfig(p.scroll)) }
        })
        scrollManager.apply(default: ScrollConfig(defaultProfile.scroll), perApp: perAppScroll)

        let perAppAuto = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in
            p.appBundleID.map { ($0, AutoScrollConfig(on: p.scroll.autoOn, button: p.scroll.autoButton, speed: p.scroll.autoSpeed)) }
        })
        let d = defaultProfile.scroll
        _ = autoScrollManager.apply(default: AutoScrollConfig(on: d.autoOn, button: d.autoButton, speed: d.autoSpeed),
                                    perApp: perAppAuto)
        pushPointer(active.pointer)
    }

    // MARK: - Scroll / pointer (per-profile)

    /// What the UI edits — the selected profile's settings.
    var editingScroll: ScrollSettings { editingProfile.scroll }
    var editingPointer: PointerSettings { editingProfile.pointer }

    func updateScroll(_ change: (inout ScrollSettings) -> Void) {
        if !AccessibilityService.shared.trusted { AccessibilityService.shared.request() }
        mutateEditing { change(&$0.scroll) }
    }

    func updatePointer(_ change: (inout PointerSettings) -> Void) {
        mutateEditing { change(&$0.pointer) }
    }

    // MARK: - Button layer (per-profile)

    var editingLayer: LayerConfig { editingProfile.layer }

    func updateLayer(_ change: (inout LayerConfig) -> Void) {
        mutateEditing { change(&$0.layer) }
    }

    /// One shift key's action for a target button + phase (disabled when unset).
    func layerAction(hold: MouseTrigger, for target: MouseTrigger, phase: ClickPhase) -> Action {
        editingLayer.mappings(for: hold).first { $0.trigger == target }?.action(for: phase) ?? .disabled
    }

    /// Save a combo into ITS hold key's list — other hold keys' combos are never touched.
    func setLayerAction(_ action: Action, hold: MouseTrigger, for target: MouseTrigger, phase: ClickPhase) {
        updateLayer { layer in
            var li = layer.layers.firstIndex { $0.hold == hold }
            if li == nil {
                layer.layers.append(HoldLayer(hold: hold))
                li = layer.layers.count - 1
            }
            if let i = layer.layers[li!].mappings.firstIndex(where: { $0.trigger == target }) {
                layer.layers[li!].mappings[i].setAction(action, for: phase)
            } else {
                var mapping = MouseMapping(trigger: target, action: .disabled)
                mapping.setAction(action, for: phase)
                layer.layers[li!].mappings.append(mapping)
            }
        }
    }

    /// Delete a shift key's ENTIRE combo record — other shift keys keep theirs.
    func removeLayer(hold: MouseTrigger) {
        updateLayer { layer in layer.layers.removeAll { $0.hold == hold } }
    }

    /// Combos configured across ALL shift keys (for the group's subtitle).
    var layerActionCount: Int {
        editingLayer.layers.reduce(0) { $0 + actionCount(in: $1.mappings) }
    }

    /// Combos configured for ONE shift key (chip badges, lock gate).
    func layerActionCount(hold: MouseTrigger) -> Int {
        actionCount(in: editingLayer.mappings(for: hold))
    }

    /// True when this button powers Mouse Shift (has ≥1 combo) — its Hold phase is locked.
    func isShiftHold(_ trigger: MouseTrigger) -> Bool {
        editingLayer.enabled && layerActionCount(hold: trigger) > 0
    }

    private func actionCount(in mappings: [MouseMapping]) -> Int {
        mappings.reduce(0) { count, m in
            count + ClickPhase.allCases.filter { m.action(for: $0).kind != .disabled }.count
        }
    }

    /// The Default ("All apps") scroll settings — the menu-bar quick toggle edits these.
    var defaultScroll: ScrollSettings { defaultProfile.scroll }

    func updateDefaultScroll(_ change: (inout ScrollSettings) -> Void) {
        guard let i = profiles.firstIndex(where: { $0.isDefault }) else { return }
        change(&profiles[i].scroll)
        repository.saveProfiles(profiles)
        applyActive()
    }

    private func pushPointer(_ p: PointerSettings) {
        guard p.override else { pointerManager.setAcceleration(pointerSystemDefault); return }
        pointerManager.setAcceleration(p.value <= 0 ? -1 : p.value)   // 0 → flat 1:1
    }

    /// Restore the system pointer default (called on quit).
    func restorePointerDefault() { pointerManager.setAcceleration(pointerSystemDefault) }

    func setSwapButtons(_ on: Bool) {
        swapButtons = on
        defaults.set(on, forKey: Keys.Defaults.mouseSwap)
        applyActive()
    }

    private func registerActivationObserver() {
        guard activationObserver == nil else { return }
        // Tell the permission service how to switch this module off (it calls this when a check
        // finds Accessibility missing). Registered once.
        AccessibilityService.shared.registerGate { [weak self] in self?.setMasterEnabled(false) }
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
        if on, !AccessibilityService.shared.trusted { AccessibilityService.shared.request() }
        applyActive()          // starts/keeps the tap alive when on; empties mappings (passthrough) when off
        if !on { stopScan() }
    }

    /// Top-level master — off pauses every mouse engine at once; on restores each section's own setting.
    func setMasterEnabled(_ on: Bool) {
        masterEnabled = on
        defaults.set(on, forKey: Keys.Defaults.mouseMasterOn)
        if on, !AccessibilityService.shared.trusted { AccessibilityService.shared.request() }
        applyActive()
        debouncer.apply(enabled: on && debounce, thresholdMs: debounceMs)
        if !on { stopScan() }
    }

    // MARK: - Scan (press buttons; they light up on the mouse)

    /// Enter scan mode — mouse buttons (listen-only) and keystroke buttons (swallowed so they
    /// don't fire) both light up their slot. Stays on until Done or a few idle seconds pass.
    func startScan() {
        if !AccessibilityService.shared.trusted { AccessibilityService.shared.request() }
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
