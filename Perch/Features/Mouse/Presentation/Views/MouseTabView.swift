//
//  MouseTabView.swift
//  Perch
//
//  The Mouse tab: an interactive mouse diagram (left) whose selected button is edited in a
//  detail panel (right), per-app profile tiles, plus Pointer / Scrolling / Reliability.
//  Buttons appear as they're scanned; keystroke buttons fill the extra slots.
//

import SwiftUI

struct MouseTabView: View {
    @Environment(MouseViewModel.self) private var mouse

    // Reactive read — when the grant flips (watcher/activation), the tile + dimming auto-update.
    private var trusted: Bool { AccessibilityService.shared.isTrusted }
    /// Controls are live only when Accessibility is granted AND the module master is on.
    private var moduleActive: Bool { trusted && mouse.masterEnabled }
    @State private var monitoring = InputMonitoringService.shared.trusted
    @State private var showingReset = false
    @State private var showingMouseIntro = false   // "What you get" showcase sheet

    // Button layer — selection state only; the config lives on the editing profile.
    @State private var layerSel = "left"                      // selected target hotspot
    @State private var layerHoldPick: MouseTrigger?           // which shift key is being EDITED
    @State private var layerSlotPicking: LayerSlotPick?
    @State private var layerHoldWarning: LayerHoldWarning?    // confirm-before-first-shift-action
    @State private var layerDeleteConfirm = false             // confirm deleting a hold key's combos
    @State private var layerIntroShowing = false              // the auto-playing how-it-works demo
    @State private var profileIntroShowing = false            // per-app profiles, in mouse language

    private struct LayerHoldWarning: Identifiable {
        let id = UUID()
        let holdLabel: String          // the Hold action that will be removed
        let pendingPick: LayerSlotPick // the slot the user was about to set
    }
    @State private var clickPick: ClickPick?
    @State private var gesturePick: GesturePick?
    @State private var targetPrompt: MappingTarget?
    @State private var addingProfile = false
    @State private var selDiagram = "middle"
    @State private var hoveredProfile: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageHeader("Mouse", subtitle: mouse.deviceSubtitle)
                    Spacer()
                    // Reset only makes sense on a usable tab — hidden when locked or paused.
                    if trusted && mouse.masterEnabled {
                        HeaderIconButton(icon: "arrow.counterclockwise",
                                         help: "Reset Mouse settings to default — your mappings, gestures and profiles aren't affected") {
                            showingReset = true
                        }
                    }
                }
                // Tile appears only when Accessibility is off (nothing else is ever hidden).
                if !trusted {
                    PermissionTile(
                        icon: "cursorarrow.click",
                        title: "Accessibility needed",
                        message: "Perch needs Accessibility to remap your mouse buttons, gestures and scroll.",
                        onGrant: { AccessibilityService.shared.request() },
                        onShowIntro: { showingMouseIntro = true })
                }
                // Input Monitoring is OPTIONAL — it only adds device details (connected mice + names).
                if !monitoring {
                    AccessibilityBanner(message: "Allow Input Monitoring to see your connected mouse and their details.",
                                        openSettings: { InputMonitoringService.shared.openSettings() })
                }
                // Master: interactive only when Accessibility is on; dimmed (not hidden) when off.
                masterGroup
                    .disabled(!trusted)
                    .opacity(trusted ? 1 : 0.5)
                // Controls: live only when Accessibility is on AND the master is on.
                Group {
                    GroupBox { profileStrip.padding(6) }
                    buttonsGroup
                    layerGroup
                    swapGroup
                    pointerGroup
                    scrollGroup
                    reliabilityGroup
                }
                .opacity(moduleActive ? 1 : 0.4)
                .disabled(!moduleActive)
            }
            .padding(20)
        }
        .sheet(isPresented: $showingMouseIntro) {
            ShowcaseSheet(title: "Mouse", content: AnyView(MouseIntroView()))
        }
        .onAppear {
            AccessibilityService.shared.refresh()
            monitoring = InputMonitoringService.shared.trusted
        }
        .onDisappear { mouse.stopScan() }
        .sheet(isPresented: $addingProfile) {
            AppPickerSheet { ids in ids.forEach { mouse.addProfile(bundleID: $0) } }
        }
        .sheet(item: $clickPick) { pick in
            ActionPicker { kind in pickClick(kind, trigger: pick.trigger, phase: pick.phase) }
        }
        .sheet(item: $gesturePick) { pick in
            ActionPicker { kind in mouse.setGestureAction(Action(kind: kind), for: pick.button, direction: pick.direction) }
        }
        .sheet(item: $targetPrompt) { targetSheet($0) }
        .sheet(isPresented: $profileIntroShowing) { profileIntroSheet }
        .alert("Reset Mouse to default?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Default", role: .destructive) {
                ConfigService.resetAll(prefix: "mouse.")
                mouse.reload()   // owns buttons, scroll and pointer now
            }
        } message: {
            Text("""
            This clears everything on the Mouse tab and can't be undone:
            • All button mappings and gestures
            • Detected & added buttons
            • Every per-app profile
            • Pointer, scrolling and reliability settings
            """)
        }
    }

    // MARK: - Per-app profile (shared component)

    /// "All apps" or the app's name — shown in the Pointer/Scroll group titles.
    private var profileLabel: String {
        mouse.isEditingDefault ? "All apps" : mouse.editingProfileName
    }

    private var profileStrip: some View {
        AppProfileStrip(
            items: [AppProfileStrip.Item(bundleID: nil, name: "All apps")]
                + mouse.appProfiles.map { AppProfileStrip.Item(bundleID: $0.appBundleID, name: $0.displayName) },
            selectedBundleID: mouse.editingBundleID,
            subtitle: mouse.isEditingDefault
                ? "Applies to every app without its own profile."
                : "Active only while \(mouse.editingProfileName) is frontmost.",
            onSelect: { mouse.selectProfile($0) },
            onAdd: { addingProfile = true },
            onRemove: { bundleID in mouse.selectProfile(bundleID); mouse.removeEditingProfile() },
            onInfo: { profileIntroShowing = true }
        )
    }

    /// The profile concept told in MOUSE language — the Keys tab tells its own version.
    private var profileIntroSheet: some View {
        ProfileIntroSheet(
            title: "How per-app profiles work",
            subtitle: "Your mouse follows whichever app is in front — automatically.",
            tip: "Add an app with the + tile, then change anything below for just that app.",
            scenes: [
                ProfileDemoScene(appName: "WhatsApp", appIcon: "message.fill",
                                 pressLabel: "Click Back", pressIcon: "computermouse",
                                 action: "Spotlight", actionIcon: "magnifyingglass",
                                 highlighted: true,
                                 caption: "WhatsApp is in front — its profile answers the click."),
                ProfileDemoScene(appName: "Browser", appIcon: "globe",
                                 pressLabel: "Click Back", pressIcon: "computermouse",
                                 action: "Normal click", actionIcon: "cursorarrow.click",
                                 highlighted: false,
                                 caption: "Same button in the browser — no profile here, so it just clicks. The switch is automatic."),
                ProfileDemoScene(appName: "WhatsApp", appIcon: "message.fill",
                                 pressLabel: "Scroll wheel", pressIcon: "scroll",
                                 action: "Slow & smooth", actionIcon: "dial.low",
                                 highlighted: true,
                                 caption: "Scrolling too — gentle in a chat, so you never fly past messages."),
                ProfileDemoScene(appName: "Browser", appIcon: "globe",
                                 pressLabel: "Scroll wheel", pressIcon: "scroll",
                                 action: "Fast 3×", actionIcon: "dial.high",
                                 highlighted: true,
                                 caption: "The same wheel races through long pages in the browser."),
                ProfileDemoScene(appName: "Figma", appIcon: "paintbrush.pointed.fill",
                                 pressLabel: "Hold Forward", pressIcon: "computermouse",
                                 action: "Zoom In", actionIcon: "plus.magnifyingglass",
                                 highlighted: true,
                                 caption: "Any app can get its own tricks — a zoom button just for design work."),
            ])
    }

    // MARK: - Scroll / Pointer / Reliability

    private var scrollGroup: some View {
        GroupBox("Scroll — \(profileLabel)") {
            VStack(spacing: 10) {
                SettingRow(title: "Reverse scroll direction",
                           subtitle: "Reverses external mouse scroll; the trackpad is left untouched.") {
                    toggle(mouse.editingScroll.reversed) { on in mouse.updateScroll { $0.reversed = on } }
                }
                Divider()
                SettingRow(title: "Smooth scrolling",
                           subtitle: "Each wheel tick glides instead of jumping — trackpad feel on a notchy wheel.") {
                    toggle(mouse.editingScroll.smooth) { on in mouse.updateScroll { $0.smooth = on } }
                }
                Divider()
                SettingRow(title: "No acceleration (flat)",
                           subtitle: "Every notch scrolls the same amount, regardless of how fast you spin.") {
                    toggle(mouse.editingScroll.linear) { on in mouse.updateScroll { $0.linear = on } }
                }
                Divider()
                SettingRow(title: "Scroll speed", subtitle: "Faster or slower than the system default.") {
                    slider(mouse.editingScroll.speed, in: 0.25...10, step: 0.25, format: "%.2f×") { v in
                        mouse.updateScroll { $0.speed = v }
                    }
                }
                Divider()
                SettingRow(title: "Turbo scroll",
                           subtitle: mouse.editingScroll.turboOn
                               ? "Hold \(mouse.editingScroll.turboKey.rawValue.prefix(1)) while scrolling for \(String(format: "%.1f", mouse.editingScroll.turboSpeed))× speed."
                               : "Hold a key while scrolling to go extra fast — for very long pages.") {
                    toggle(mouse.editingScroll.turboOn) { on in mouse.updateScroll { $0.turboOn = on } }
                }
                if mouse.editingScroll.turboOn {
                    SettingRow(title: "Hold key",
                               subtitle: mouse.editingScroll.turboKey == .control
                                   ? "⌃ can conflict with macOS scroll-zoom if you enabled it in Accessibility."
                                   : "Held only while you want the boost.") {
                        Picker("", selection: Binding(get: { mouse.editingScroll.turboKey },
                                                      set: { key in mouse.updateScroll { $0.turboKey = key } })) {
                            ForEach(TurboKey.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                    }
                    SettingRow(title: "Turbo speed", subtitle: "Multiplies your scroll speed while the key is held.") {
                        slider(mouse.editingScroll.turboSpeed, in: 2...10, step: 0.5, format: "%.1f×") { v in
                            mouse.updateScroll { $0.turboSpeed = v }
                        }
                    }
                }
                Divider()
                SettingRow(title: "Auto-scroll",
                           subtitle: "Long-press the middle button, then move to scroll. Release to keep scrolling; any click stops.") {
                    toggle(mouse.editingScroll.autoOn) { on in mouse.updateScroll { $0.autoOn = on } }
                }
                if mouse.editingScroll.autoOn {
                    SettingRow(title: "Sensitivity") {
                        slider(mouse.editingScroll.autoSpeed, in: 0.1...4, step: 0.05, format: "%.2f×") { v in
                            mouse.updateScroll { $0.autoSpeed = v }
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private var pointerGroup: some View {
        GroupBox("Pointer — \(profileLabel)") {
            VStack(spacing: 10) {
                SettingRow(title: "Control pointer acceleration",
                           subtitle: "Override macOS cursor acceleration — off leaves the system default.") {
                    toggle(mouse.editingPointer.override) { on in mouse.updatePointer { $0.override = on } }
                }
                if mouse.editingPointer.override {
                    Divider()
                    SettingRow(title: "Acceleration", subtitle: "0 = flat 1:1 tracking; higher = more.") {
                        slider(mouse.editingPointer.value, in: 0...20, step: 0.5, format: "%.1f") { v in
                            mouse.updatePointer { $0.value = v }
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private var reliabilityGroup: some View {
        GroupBox("Reliability") {
            VStack(spacing: 10) {
                SettingRow(title: "Ignore accidental double-clicks",
                           subtitle: "Fixes a worn switch that fires twice on one press.") {
                    toggle(mouse.debounce) { mouse.setDebounce($0) }
                }
                if mouse.debounce {
                    SettingRow(title: "Ignore window", subtitle: "A second click within this time is dropped.") {
                        slider(mouse.debounceMs, in: 20...100, step: 5, format: "%.0f ms") { mouse.setDebounceMs($0) }
                    }
                }
            }
            .padding(6)
        }
    }

    // MARK: - No mouse

    private var noMouse: some View {
        VStack(spacing: 12) {
            Image(systemName: "computermouse")
                .font(.system(size: 46, weight: .light)).foregroundStyle(.tertiary)
            Text("No mouse connected").font(.headline)
            Text("Connect a mouse to set up its buttons, scrolling, and gestures.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    // MARK: - Master

    private var masterGroup: some View {
        GroupBox {
            SettingRow(title: "Enable Mouse",
                       subtitle: "Master switch for the whole tab — buttons, scroll, pointer and gestures. Applies to all mice.") {
                toggle(mouse.masterEnabled) { mouse.setMasterEnabled($0) }
            }
            .padding(6)
        }
    }

    // MARK: - Buttons

    private var buttonsGroup: some View {
        GroupBox("Buttons — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Enable button mapping",
                           subtitle: "Assign buttons to shortcuts, actions, and gestures.") {
                    toggle(mouse.isEnabled) { mouse.setEnabled($0) }
                }
                Divider()
                detect
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 8) {
                            MouseDiagramView(selected: $selDiagram, isMapped: isMappedHotspot, isActive: isActiveHotspot, onSelect: handleDiagramTap)
                                .padding(.leading, 4)
                                .onChange(of: mouse.addCount) { _, _ in
                                    if let t = mouse.lastAdded, let id = hotspotFor(t) { selDiagram = id }
                                }
                            Text("Click a button").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        Divider()
                        detailPanel.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(mouse.isEnabled ? 1 : 0.4)
                .disabled(!mouse.isEnabled)
            }
            .padding(6)
        }
    }

    /// Handedness — its own box after the layer (was an odd last row inside Buttons).
    private var swapGroup: some View {
        GroupBox {
            SettingRow(title: "Swap primary & secondary buttons",
                       subtitle: "Left-handed use — left click becomes right click and vice versa.") {
                toggle(mouse.swapButtons) { mouse.setSwapButtons($0) }
            }
            .padding(6)
        }
        .opacity(mouse.isEnabled ? 1 : 0.5)
        .disabled(!mouse.isEnabled)
    }

    // MARK: - Button layer (UI preview — own group, expands when enabled)

    private struct LayerSlotPick: Identifiable {
        let id: String
        let target: String        // diagram hotspot id
        let phase: ClickPhase
    }

    /// Diagram hotspot id → friendly name (matches the Buttons section naming).
    private static let layerNames: [String: String] = [
        "left": "Left click", "right": "Right click", "middle": "Middle", "top": "Top",
        "back": "Back (4)", "fwd": "Forward (5)", "rup": "Button 6", "rdn": "Button 7",
    ]
    /// Buttons that can power the layer: Middle + the DETECTED list — the exact same triggers
    /// (and names) the Buttons section uses. No hardcoded back/forward guessing: the chip's
    /// identity IS the trigger the mouse actually sent during detection.
    private var layerHoldChoices: [MouseTrigger] {
        [.button(2)] + mouse.detectedButtons.filter { trigger in
            if case .button(let n) = trigger { return n >= 3 } else { return false }
        }
    }

    /// The shift key currently being EDITED. Switching only changes which combo set is
    /// shown — every other shift key's combos stay saved untouched.
    private var layerHoldSelected: MouseTrigger {
        layerHoldPick ?? mouse.editingLayer.layers.first?.hold ?? .button(2)
    }

    /// Display name — identical to how the Buttons section names it.
    private var layerHoldName: String {
        layerHoldSelected == .button(2) ? "Middle" : layerHoldSelected.displayName
    }

    /// The edited shift key's hotspot for the diagram's amber highlight. Other shift keys
    /// stay selectable — they're legal TARGETS under this key's layer.
    private var layerHoldIDs: Set<String> {
        Set([layerHoldSelected].compactMap(hotspotFor))
    }

    private var layerGroup: some View {
        let layerOn = mouse.editingLayer.enabled
        let count = mouse.layerActionCount
        return GroupBox("Mouse Shift — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Enable Mouse Shift",
                           subtitle: layerOn
                               ? "Hold a shift key, then press another button — it runs that combo's action. \(count) combo\(count == 1 ? "" : "s") set."
                               : "Hold one button to give every other button a second set of actions — like ⇧ for your mouse.") {
                    HStack(spacing: 10) {
                        Button { layerIntroShowing = true } label: {
                            Image(systemName: "info.circle").font(.system(size: 16)).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("See how Mouse Shift works")
                        Toggle("", isOn: Binding(get: { mouse.editingLayer.enabled },
                                                 set: { on in mouse.updateLayer { $0.enabled = on } }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                if layerOn {
                    Divider()
                    // Hold-button chips — the amber button on the map is the one you hold.
                    HStack(spacing: 6) {
                        Text("Hold button")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        ForEach(layerHoldChoices, id: \.self) { trigger in
                            let editing = layerHoldSelected == trigger
                            let combos = mouse.layerActionCount(hold: trigger)
                            let name = trigger == .button(2) ? "Middle" : trigger.displayName
                            Button {
                                // Switch which shift key's combos are shown — nothing is
                                // deleted or replaced; every key's combos stay saved.
                                layerHoldPick = trigger
                                if hotspotFor(trigger) == layerSel { layerSel = "left" }
                            } label: {
                                // Editing key = solid amber HOLD; keys with saved combos
                                // show their count so nothing feels lost when switching.
                                Text(editing ? "HOLD · \(name)" : (combos > 0 ? "\(name) · \(combos)" : name))
                                    .font(.system(size: 11, weight: editing ? .bold : .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(editing ? AnyShapeStyle(Color.secondaryAccent)
                                                : combos > 0 ? AnyShapeStyle(Color.secondaryAccent.opacity(0.15))
                                                             : AnyShapeStyle(Color.primary.opacity(0.06)),
                                                in: Capsule())
                                    .foregroundStyle(editing ? Color.white : (combos > 0 ? Color.secondaryAccent : Color.secondary))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // No extra buttons yet → guide the user to the one detection system.
                    if layerHoldChoices.count == 1 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").font(.system(size: 16)).foregroundStyle(.secondary)
                            Text("Only Middle can power the layer right now — scan your mouse's extra buttons to unlock more.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            if mouse.scanning {
                                HStack(spacing: 6) {
                                    Circle().fill(.green).frame(width: 6, height: 6)
                                    Text("Press your buttons…").font(.system(size: 11, weight: .medium))
                                }
                            } else {
                                Button("Scan buttons") { mouse.startScan() }
                                    .font(.system(size: 11))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                    holdConflictTile
                    Divider()
                    // Master-detail: our diagram (amber hold) + the slot editor.
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 8) {
                            MouseDiagramView(selected: $layerSel,
                                             isMapped: { id in
                                                 guard let t = triggerFor(id) else { return false }
                                                 return ClickPhase.allCases.contains { mouse.layerAction(hold: layerHoldSelected, for: t, phase: $0).kind != .disabled }
                                             },
                                             isActive: isActiveHotspot,   // same detection as the Buttons diagram
                                             holdIDs: layerHoldIDs,
                                             onSelect: { layerSel = $0 })
                                .padding(.leading, 4)
                            Text("Hold the amber button, then click any other\nbutton here to set its second action.")
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Hold").font(.system(size: 12)).foregroundStyle(.secondary)
                                Text(layerHoldName).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondaryAccent)
                                Text(", then").font(.system(size: 12)).foregroundStyle(.secondary)
                                Text(layerName(layerSel).lowercased()).font(.system(size: 12, weight: .semibold))
                                Spacer()
                                // Same revert affordance as the Buttons panel — wipes THIS
                                // shift key's whole combo record after a confirm.
                                if mouse.layerActionCount(hold: layerHoldSelected) > 0 {
                                    Button { layerDeleteConfirm = true } label: {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete all of \(layerHoldName)'s combos")
                                    .alert("Delete \(layerHoldName)'s combos?", isPresented: $layerDeleteConfirm) {
                                        Button("Cancel", role: .cancel) {}
                                        Button("Delete", role: .destructive) {
                                            mouse.removeLayer(hold: layerHoldSelected)
                                        }
                                    } message: {
                                        Text("All \(mouse.layerActionCount(hold: layerHoldSelected)) combo\(mouse.layerActionCount(hold: layerHoldSelected) == 1 ? "" : "s") under \(layerHoldName) are removed. Other shift keys keep theirs.")
                                    }
                                }
                            }
                            .padding(.bottom, 6)
                            Divider()
                            ForEach(ClickPhase.allCases) { phase in
                                layerSlotRow(target: layerSel, phase: phase)
                            }
                            Spacer(minLength: 8)
                            Text("Left and right click are safe to set here — the layer only applies while \(layerHoldName) is held down.")
                                .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(6)
        }
        .opacity(mouse.isEnabled ? 1 : 0.5)
        .disabled(!mouse.isEnabled)
        .alert(item: $layerHoldWarning) { layerHoldAlert($0) }
        .sheet(isPresented: $layerIntroShowing) { MouseShiftIntroSheet() }
        .sheet(item: $layerSlotPicking) { pick in
            ActionPicker(excluding: [.passThrough]) { kind in
                guard let trigger = triggerFor(pick.target) else { return }
                if kind.target == .none {
                    mouse.setLayerAction(Action(kind: kind), hold: layerHoldSelected, for: trigger, phase: pick.phase)
                } else {
                    // Needs a target (app / keystroke / script…) — same prompt flow as Buttons.
                    targetPrompt = MappingTarget(trigger: trigger, phase: pick.phase, kind: kind, layerHold: layerHoldSelected)
                }
            }
        }
    }

    private func layerName(_ id: String) -> String { Self.layerNames[id] ?? id }

    /// The Hold action's label if this button has one — that's the only real conflict with
    /// Mouse Shift (holding IS the shift gesture; click and double-click keep working).
    private func holdConflict(for trigger: MouseTrigger) -> String? {
        let action = mouse.action(for: trigger, phase: .hold)
        return action.kind == .disabled ? nil : action.displayLabel
    }

    /// Passive warning tile — the chosen hold button still has a Hold action. Nothing is
    /// removed yet; the confirm happens the moment the user sets their first shift action.
    @ViewBuilder
    private var holdConflictTile: some View {
        if let conflict = holdConflict(for: layerHoldSelected) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryAccent)
                    .frame(width: 26, height: 26)
                    .background(Color.secondaryAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(layerHoldName).font(.system(size: 13, weight: .semibold))
                        Text("HOLD IN USE")
                            .font(.system(size: 9, weight: .bold)).kerning(0.5)
                            .foregroundStyle(Color.secondaryAccent)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.secondaryAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text("Its Hold action — \(conflict) — will be removed when you set its first shift combo. Click and double-click keep working.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.secondaryAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Confirm at the moment of commitment: remove the old Hold action, then open the picker.
    private func layerHoldAlert(_ warning: LayerHoldWarning) -> Alert {
        Alert(
            title: Text("Remove \(layerHoldName)'s Hold action?"),
            message: Text("\(layerHoldName) uses Hold for “\(warning.holdLabel)”. Holding becomes the shift gesture, so that action is removed first — then pick your shift action. Click and double-click keep working."),
            primaryButton: .destructive(Text("Remove & Continue")) {
                mouse.setAction(.disabled, for: layerHoldSelected, phase: .hold)
                let pick = warning.pendingPick
                DispatchQueue.main.async { layerSlotPicking = pick }   // after the alert dismisses
            },
            secondaryButton: .cancel()
        )
    }


    private func layerPhaseLabel(_ phase: ClickPhase) -> String {
        switch phase {
        case .single: return "Click"
        case .double: return "Double click"
        case .hold:   return "Hold"
        }
    }

    private func layerSlotRow(target: String, phase: ClickPhase) -> some View {
        let action = triggerFor(target).map { mouse.layerAction(hold: layerHoldSelected, for: $0, phase: phase) } ?? .disabled
        let off = action.kind == .disabled
        return Button {
            let pick = LayerSlotPick(id: "\(target)|\(phase.rawValue)", target: target, phase: phase)
            // Commitment point: this shift key's old Hold action must go before its combos exist.
            if let conflict = holdConflict(for: layerHoldSelected) {
                layerHoldWarning = LayerHoldWarning(holdLabel: conflict, pendingPick: pick)
            } else {
                layerSlotPicking = pick
            }
        } label: {
            HStack(spacing: 8) {
                Text(layerPhaseLabel(phase))
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 100, alignment: .leading)
                Spacer(minLength: 8)
                Text(off ? "—" : action.displayLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(off ? .tertiary : .secondary)
                    .lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // The right-hand panel: everything the selected button does — its Click / Double / Hold
    // and (for the wheel) its gesture. Wired to the engine by trigger.
    @ViewBuilder
    private var detailPanel: some View {
        let id = selDiagram
        let meta = hotspotMeta(id)
        VStack(alignment: .leading, spacing: 12) {
            panelHeader(meta)
            if meta.locked {
                Text("\(meta.name) is your normal click and can't be remapped. Pick another button on the mouse.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else if let trigger = triggerFor(id) {
                // Only the HOLD phase conflicts with Mouse Shift (holding IS the shift gesture);
                // click and double-click keep working on the shift key. The lock appears only
                // once the user has COMMITTED — at least one shift action set — never before.
                let isShiftKey = mouse.isShiftHold(trigger)
                block("CLICK") {
                    let phases = phases(forTrigger: trigger)
                    ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                        if index > 0 { Divider() }
                        if isShiftKey && phase == .hold {
                            HStack(spacing: 8) {
                                Text(phase.title).font(.system(size: 12, weight: .medium))
                                    .frame(width: 100, alignment: .leading)
                                Spacer(minLength: 8)
                                Text("Powers Mouse Shift")
                                    .font(.system(size: 12)).foregroundStyle(Color.secondaryAccent)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9)).foregroundStyle(Color.secondaryAccent)
                            }
                            .frame(minHeight: 36)
                        } else {
                            panelRow(phase.title, action: mouse.action(for: trigger, phase: phase),
                                     fallback: predefinedLabel(trigger, phase)) {
                                clickPick = ClickPick(trigger: trigger, phase: phase)
                            }
                        }
                    }
                }
                if meta.gestures {
                    block("GESTURE · HOLD & FLICK") {
                        ForEach(Array(GestureDirection.allCases.enumerated()), id: \.element) { index, direction in
                            if index > 0 { Divider() }
                            panelRow(direction.title, action: mouse.gestureAction(for: 2, direction: direction)) {
                                gesturePick = GesturePick(button: 2, direction: direction)
                            }
                        }
                    }
                }
            }
        }
    }

    private func panelHeader(_ meta: HotspotMeta) -> some View {
        HStack(spacing: 9) {
            Image(systemName: meta.icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26).background(Color.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(meta.name).font(.system(size: 13, weight: .semibold))
                Text(meta.sub).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if let t = triggerFor(selDiagram) {
                if case .key = t {
                    Button { mouse.removeWhitelisted(t); selDiagram = "middle" } label: {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless).help("Remove this keystroke button")
                } else if let m = mouse.mapping(for: t) {
                    Button { mouse.removeMapping(m.id) } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless).help("Reset this button")
                }
            }
        }
    }

    @ViewBuilder
    private var detect: some View {
        if mouse.scanning {
            HStack(spacing: 10) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("Scanning — press each button on your mouse. Don't touch the keyboard.")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button("Done") { mouse.stopScan() }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else {
            HStack(spacing: 10) {
                Button { mouse.startScan() } label: { Label("Scan buttons", systemImage: "dot.viewfinder") }
                Text("Press your mouse's extra buttons to add them — even ones that type a shortcut.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }


    // MARK: - Card pieces

    private func block<Content: View>(_ label: String, onRemove: (() -> Void)? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.4)
                Spacer()
                if let onRemove {
                    Button(action: onRemove) { Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.tertiary) }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.bottom, 4)
            content()
        }
    }

    // Clean detail row: name on the left, current action on the right, a chevron. When unset,
    // a `fallback` (the button's predefined default, e.g. Back/Forward) shows tagged "default".
    private func panelRow(_ title: String, action: Action, fallback: String? = nil,
                          onTap: @escaping () -> Void) -> some View {
        let off = action.kind == .disabled
        let value = off ? (fallback ?? "—") : action.displayLabel
        let muted = off && fallback == nil
        return Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 12, weight: .medium)).frame(width: 100, alignment: .leading)
                Spacer(minLength: 8)
                Text(value).font(.system(size: 12)).foregroundStyle(muted ? .tertiary : .secondary)
                    .lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Buttons that already do something on macOS by default (shown until the user overrides).
    private func predefinedLabel(_ trigger: MouseTrigger, _ phase: ClickPhase) -> String? {
        guard case .single = phase else { return nil }
        switch trigger {
        case .button(3): return "Back"
        case .button(4): return "Forward"
        default:         return nil
        }
    }

    private func toggle(_ isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: action)).toggleStyle(.switch).labelsHidden()
    }

    // Continuous slider (no `step`) so macOS doesn't draw tick dots; we snap to the step ourselves.
    private func slider(_ value: Double, in range: ClosedRange<Double>, step: Double, format: String,
                        action: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: { action(($0 / step).rounded() * step) }), in: range)
                .frame(width: 140)
            Text(String(format: format, value)).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
        }
    }


    // MARK: - Data helpers

    private func buttonNumber(_ trigger: MouseTrigger) -> Int? {
        if case .button(let n) = trigger { return n }
        return nil
    }

    // MARK: - Diagram

    /// Map a diagram hotspot to its trigger (thumb = the first registered keystroke button).
    private func triggerFor(_ id: String) -> MouseTrigger? {
        switch id {
        case "left":   return .button(0)
        case "right":  return .button(1)
        case "middle": return .button(2)
        case "back":   return .button(3)
        case "fwd":    return .button(4)
        case "top":    return additionalTriggers.count > 0 ? additionalTriggers[0] : nil
        case "rup":    return additionalTriggers.count > 1 ? additionalTriggers[1] : nil
        case "rdn":    return additionalTriggers.count > 2 ? additionalTriggers[2] : nil
        default:       return nil
        }
    }

    /// The user's additional buttons — detected physical extras (button 5+) plus registered
    /// keystroke buttons — filling the mouse's extra slots (Top, then right 6/7).
    private var additionalTriggers: [MouseTrigger] {
        let extraPhysical = mouse.detectedButtons.filter {
            if case .button(let n) = $0 { return n >= 5 } else { return false }
        }
        return extraPhysical + mouse.whitelist
    }

    /// Base buttons always show; Back/Forward once detected; the extra slots once an
    /// additional button (detected physical or keystroke) fills them.
    private func isActiveHotspot(_ id: String) -> Bool {
        switch id {
        case "left", "right", "middle": return true
        case "back": return mouse.detectedButtons.contains(.button(3))
        case "fwd":  return mouse.detectedButtons.contains(.button(4))
        case "top":  return additionalTriggers.count > 0
        case "rup":  return additionalTriggers.count > 1
        case "rdn":  return additionalTriggers.count > 2
        default:     return false
        }
    }

    /// Trigger → diagram hotspot (for auto-selecting a freshly detected/registered button).
    private func hotspotFor(_ trigger: MouseTrigger) -> String? {
        switch trigger {
        case .button(0): return "left"
        case .button(1): return "right"
        case .button(2): return "middle"
        case .button(3): return "back"
        case .button(4): return "fwd"
        default:
            guard let i = additionalTriggers.firstIndex(of: trigger), i < 3 else { return nil }
            return ["top", "rup", "rdn"][i]
        }
    }

    private func isMappedHotspot(_ id: String) -> Bool {
        guard let t = triggerFor(id), buttonNumber(t).map({ $0 > 1 }) ?? true else { return false }
        if id == "middle", !mouse.gestures.contains(where: { $0.button == 2 }) {
            return mouse.mapping(for: t) != nil
        }
        return mouse.mapping(for: t) != nil || (id == "middle" && !mouse.gestures.isEmpty)
    }

    /// Clicking a button on the map selects it — the detail panel edits it on the right.
    private func handleDiagramTap(_ id: String) {
        selDiagram = id
    }

    private struct HotspotMeta { let name, sub, icon: String; let locked, gestures: Bool }

    private func hotspotMeta(_ id: String) -> HotspotMeta {
        switch id {
        case "left":   return .init(name: "Left", sub: "Primary click", icon: "cursorarrow.click", locked: true, gestures: false)
        case "right":  return .init(name: "Right", sub: "Secondary click", icon: "cursorarrow.click", locked: true, gestures: false)
        case "middle": return .init(name: "Middle", sub: "Wheel click", icon: "computermouse", locked: false, gestures: true)
        case "top":    return .init(name: "Top", sub: "Top button", icon: "computermouse", locked: false, gestures: false)
        case "back":   return .init(name: "Back", sub: "Side button 4", icon: "arrow.left", locked: false, gestures: false)
        case "fwd":    return .init(name: "Forward", sub: "Side button 5", icon: "arrow.right", locked: false, gestures: false)
        default:       // rup / rdn — additional slots (physical extra or keystroke)
            if let t = triggerFor(id) {
                if case .key = t {
                    return .init(name: t.displayName, sub: "Keystroke button", icon: "keyboard", locked: false, gestures: false)
                }
                return .init(name: t.displayName, sub: "Additional button", icon: "computermouse", locked: false, gestures: false)
            }
            return .init(name: "Extra", sub: "Additional button", icon: "computermouse", locked: false, gestures: false)
        }
    }

    private func phases(forTrigger trigger: MouseTrigger) -> [ClickPhase] {
        if case .key = trigger { return [.single] }
        return ClickPhase.allCases
    }

    private func pickClick(_ kind: ActionKind, trigger: MouseTrigger, phase: ClickPhase) {
        if kind.target == .none {
            mouse.setAction(Action(kind: kind), for: trigger, phase: phase)
        } else {
            targetPrompt = MappingTarget(trigger: trigger, phase: phase, kind: kind)
        }
    }

    /// Route a resolved action to the normal mapping or the right shift key's combo set.
    private func setPromptAction(_ action: Action, _ prompt: MappingTarget) {
        if let hold = prompt.layerHold {
            mouse.setLayerAction(action, hold: hold, for: prompt.trigger, phase: prompt.phase)
        } else {
            mouse.setAction(action, for: prompt.trigger, phase: prompt.phase)
        }
    }

    @ViewBuilder
    private func targetSheet(_ prompt: MappingTarget) -> some View {
        switch prompt.kind.target {
        case .app:
            AppPickerSheet(allowsMultipleSelection: false) { ids in
                if let bundle = ids.first {
                    setPromptAction(Action(kind: .openApp, target: bundle), prompt)
                }
            }
        case .keystroke:
            KeystrokeCaptureSheet { code, mods in
                setPromptAction(Action(kind: .customKeystroke, keyCode: Int(code), modifiers: mods), prompt)
            }
        case .url:
            TextTargetSheet(title: "Open URL", placeholder: "https://…") { setPromptAction(Action(kind: .openURL, target: $0), prompt) }
        case .file:
            TextTargetSheet(title: "Open File or Folder", placeholder: "/Users/…/file", allowFilePicker: true) { setPromptAction(Action(kind: .openFile, target: $0), prompt) }
        case .shellScript:
            PresetPickerSheet(title: "Run Shell Script", customPlaceholder: "echo hello", load: { ActionPresets.shell }) { setPromptAction(Action(kind: .runShell, target: $0), prompt) }
        case .appleScript:
            PresetPickerSheet(title: "Run AppleScript", customPlaceholder: "display dialog \"Hi\"", load: { ActionPresets.appleScript }) { setPromptAction(Action(kind: .runAppleScript, target: $0), prompt) }
        default:
            EmptyView()
        }
    }
}

private extension View {
    func cardBackground() -> some View {
        background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary.opacity(0.5)))
    }
}

private struct ClickPick: Identifiable { let id = UUID(); let trigger: MouseTrigger; let phase: ClickPhase }
private struct GesturePick: Identifiable { let id = UUID(); let button: Int; let direction: GestureDirection }
private struct MappingTarget: Identifiable {
    let id = UUID()
    let trigger: MouseTrigger
    let phase: ClickPhase
    let kind: ActionKind
    var layerHold: MouseTrigger? = nil   // set → the picked action lands in THIS shift key's combos
}
