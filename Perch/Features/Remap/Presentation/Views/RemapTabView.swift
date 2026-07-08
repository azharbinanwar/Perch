//
//  RemapTabView.swift
//  Perch
//
//  Keys page. Two sections: Key mappings (single key → action) and Shortcuts (combo → action).
//  Per-app profiles. One "Add mapping" flow: record the key/combo, then set the output by
//  recording a key *or* picking an action from the catalogue.
//

import SwiftUI

struct RemapTabView: View {
    @Environment(RemapViewModel.self) private var vm
    // Reactive read — when the grant flips (watcher/activation), the tile + dimming auto-update.
    private var trusted: Bool { AccessibilityService.shared.isTrusted }
    /// Controls are live only when Accessibility is granted AND the module master is on.
    private var moduleActive: Bool { trusted && vm.isEnabled }
    @State private var showingReset = false
    @State private var addingRule = false
    @State private var addingProfile = false
    @State private var picking = false               // action catalogue for the output
    @State private var targetPrompt: ActionKind?     // picked action still needs a target

    private struct ModPick: Identifiable { let id: String }
    @State private var doubleTapPicking: ModPick?
    @State private var hyperIntroShowing = false   // the auto-playing how-it-works demo
    @State private var profileIntroShowing = false // per-app profiles, in keys language
    @State private var doubleTapIntroShowing = false
    @State private var showingKeysIntro = false   // "What you get" showcase sheet


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageHeader("Keys", subtitle: "Remap keys and shortcuts, app by app.")
                    Spacer()
                    // Header actions only make sense on a usable tab (hidden behind the lock otherwise).
                    if trusted {
                        HeaderIconButton(icon: "arrow.counterclockwise",
                                         help: "Reset Keys settings to default — your mappings and profiles aren't affected") {
                            showingReset = true
                        }
                        HeaderIconButton(icon: "plus", help: "Add a key mapping") {
                            vm.clearDraft(); addingRule = true
                        }
                        .disabled(!moduleActive)
                    }
                }
                // Tile appears only when Accessibility is off (nothing else is ever hidden).
                if !trusted {
                    PermissionTile(
                        icon: "keyboard",
                        title: "Accessibility needed",
                        message: "Perch needs Accessibility to remap your keys, Hyper Key and double-tap shortcuts.",
                        onGrant: { AccessibilityService.shared.request() },
                        onShowIntro: { showingKeysIntro = true })
                }
                // Master: interactive only when Accessibility is on; dimmed (not hidden) when off.
                keyboardGroup
                    .disabled(!trusted)
                    .opacity(trusted ? 1 : 0.5)
                // Profile strip on top, like Mouse — it governs the per-app section below.
                GroupBox { profileStrip.padding(6) }
                    .opacity(moduleActive ? 1 : 0.5)
                shortcutsGroup
                hyperGroup
                doubleTapGroup
            }
            .padding(20)
        }
        .sheet(isPresented: $showingKeysIntro) {
            ShowcaseSheet(title: "Keys", content: AnyView(KeysIntroView()))
        }
        .onAppear { AccessibilityService.shared.refresh() }
        .sheet(isPresented: $hyperIntroShowing) { HyperKeyIntroSheet() }
        .sheet(isPresented: $profileIntroShowing) { profileIntroSheet }
        .sheet(isPresented: $doubleTapIntroShowing) { DoubleTapIntroSheet() }
        .sheet(isPresented: $addingRule, onDismiss: { vm.clearDraft() }) { captureSheet }
        .sheet(isPresented: $addingProfile) {
            AppPickerSheet { ids in ids.forEach { vm.addProfile(bundleID: $0) } }
        }
        .alert("Reset Keys to default?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Default", role: .destructive) {
                ConfigService.resetAll(prefix: "keys.")
                vm.reload()
            }
        } message: {
            Text("""
            This clears everything on the Keys tab and can't be undone:
            • All key and shortcut mappings
            • Every per-app profile
            • The remapping on/off setting
            """)
        }
    }

    // MARK: - Hyper Key (UI preview)

    private var hyperGroup: some View {
        let symbols = vm.hyperShift ? "⌘⌥⌃⇧" : "⌘⌥⌃"
        return GroupBox("Hyper Key — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Enable Hyper Key",
                           subtitle: "Hold Caps Lock to act as \(symbols) together — a private shortcut layer no app conflicts with.") {
                    HStack(spacing: 10) {
                        Button { hyperIntroShowing = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("See how the Hyper Key works")
                        Toggle("", isOn: Binding(get: { vm.hyperEnabled }, set: { vm.setHyperEnabled($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                if vm.hyperEnabled {
                    Divider()
                    SettingRow(title: "Single tap",
                               subtitle: "A quick tap without another key.") {
                        tapPicker(vm.hyperTap) { vm.setHyperTap($0) }
                    }
                    Divider()
                    SettingRow(title: "Double tap",
                               subtitle: "Two quick taps in a row.") {
                        tapPicker(vm.hyperDoubleTap) { vm.setHyperDoubleTap($0) }
                    }
                    Divider()
                    SettingRow(title: "Include ⇧ Shift",
                               subtitle: "Off sends ⌘⌥⌃ only — for the rare app that mishandles all four. Existing Hyper shortcuts update automatically.") {
                        Toggle("", isOn: Binding(get: { vm.hyperShift }, set: { vm.setHyperShift($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                    Label("Try it: hold Caps Lock and press M — apps see \(symbols)M, free for your own shortcuts.",
                          systemImage: "lightbulb")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(6)
        }
        .opacity(moduleActive ? 1 : 0.5)
        .disabled(!moduleActive)
    }

    private func tapPicker(_ value: HyperKeyManager.TapAction,
                           onChange: @escaping (HyperKeyManager.TapAction) -> Void) -> some View {
        Picker("", selection: Binding(get: { value }, set: onChange)) {
            ForEach(HyperKeyManager.TapAction.allCases) { Text($0.rawValue).tag($0) }
        }
        .labelsHidden().frame(width: 130)
    }

    // MARK: - Double-tap modifiers

    private var doubleTapGroup: some View {
        GroupBox("Double-Tap — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Enable double-tap",
                           subtitle: "Tap a modifier twice quickly to run an action — normal shortcuts are never affected.") {
                    HStack(spacing: 10) {
                        Button { doubleTapIntroShowing = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("See how Double-Tap works")
                        Toggle("", isOn: Binding(get: { vm.doubleTap.enabled }, set: { vm.setDoubleTapEnabled($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                if vm.doubleTap.enabled {
                    ForEach(DoubleTapManager.modifiers, id: \.key) { mod in
                        Divider()
                        doubleTapRow(mod.key, title: "Double-tap \(mod.symbol) \(mod.name)")
                    }
                }
            }
            .padding(6)
        }
        .opacity(moduleActive ? 1 : 0.5)
        .disabled(!moduleActive)
        .sheet(item: $doubleTapPicking) { pick in
            // Target-needing actions (Open App…, scripts) skipped for now — keeps the flow one click.
            ActionPicker(excluding: doubleTapExcluded) { kind in
                vm.setDoubleTapAction(kind == .disabled ? nil : Action(kind: kind), for: pick.id)
            }
        }
    }

    /// The app-wide action-slot row: name left, current action right, chevron — click to pick.
    private func doubleTapRow(_ key: String, title: String) -> some View {
        let action = vm.doubleTap.actions[key]
        return Button { doubleTapPicking = ModPick(id: key) } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 8)
                Text(action?.displayLabel ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(action == nil ? .tertiary : .secondary)
                    .lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Double-tap picks fire immediately — no target prompt flow — so exclude kinds needing one.
    private var doubleTapExcluded: Set<ActionKind> {
        Set(ActionKind.allCases.filter { $0.target != .none }).union([.passThrough])
    }

    // MARK: - Enable + profile + modifier-swap note

    private var keyboardGroup: some View {
        SettingGroup("Keyboard") {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Enable Keys",
                           subtitle: "Master switch — key remapping, Hyper Key, and double-tap. Applies to all keyboards.",
                           icon: "keyboard") {
                    Toggle("", isOn: Binding(get: { vm.isEnabled }, set: { _ in vm.toggleEnabled() }))
                        .toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }

    private var profileStrip: some View {
        AppProfileStrip(
            items: [AppProfileStrip.Item(bundleID: nil, name: "All apps")]
                + vm.appProfiles.map { AppProfileStrip.Item(bundleID: $0.appBundleID, name: $0.displayName) },
            selectedBundleID: vm.editingBundleID,
            subtitle: vm.isEditingDefault
                ? "Applies to every app without its own profile."
                : "Active only while \(vm.editingProfileName) is frontmost.",
            onSelect: { vm.selectProfile($0) },
            onAdd: { addingProfile = true },
            onRemove: { bundleID in vm.selectProfile(bundleID); vm.removeEditingProfile() },
            onInfo: { profileIntroShowing = true }
        )
    }

    /// The profile concept told in KEYS language — the Mouse tab tells its own version.
    private var profileIntroSheet: some View {
        ProfileIntroSheet(
            title: "How per-app profiles work",
            subtitle: "Your keyboard follows whichever app is in front — automatically.",
            tip: "Add an app with the + tile, then change shortcuts, Hyper Key or Double-Tap for just that app.",
            scenes: [
                ProfileDemoScene(appName: "Figma", appIcon: "paintbrush.pointed.fill",
                                 pressLabel: "Press Caps Lock + Z", pressIcon: "keyboard",
                                 action: "Zoom to Fit", actionIcon: "arrow.up.left.and.arrow.down.right",
                                 highlighted: true,
                                 caption: "Figma is in front — its profile answers the keys."),
                ProfileDemoScene(appName: "Terminal", appIcon: "terminal.fill",
                                 pressLabel: "Press Caps Lock", pressIcon: "keyboard",
                                 action: "Just Caps Lock", actionIcon: "capslock",
                                 highlighted: false,
                                 caption: "In Terminal you turned Hyper off — Caps Lock is simply Caps Lock again."),
                ProfileDemoScene(appName: "Figma", appIcon: "paintbrush.pointed.fill",
                                 pressLabel: "Double-tap ⇧", pressIcon: "keyboard",
                                 action: "Spotlight", actionIcon: "magnifyingglass",
                                 highlighted: true,
                                 caption: "Double-tap actions switch per app too. All of it follows the front app by itself."),
            ])
    }

    // MARK: - Key mappings / Shortcuts

    private var profileLabel: String {
        vm.isEditingDefault ? "All apps" : vm.editingProfileName
    }

    private var shortcutsGroup: some View {
        GroupBox("Shortcuts — \(profileLabel)") {
            ruleList(vm.rules, empty: "No mappings yet — add one with “Add mapping”.")
                .padding(6)
                .opacity(moduleActive ? 1 : 0.5)
        }
    }

    private func ruleList(_ rules: [RemapRule], empty: String) -> some View {
        Group {
            if rules.isEmpty {
                Text(empty).font(.system(size: 12)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        if index > 0 { Divider() }
                        ruleRow(rule)
                    }
                }
            }
        }
    }

    private func ruleRow(_ rule: RemapRule) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in vm.toggleRule(rule) }))
                .toggleStyle(.switch).labelsHidden().scaleEffect(0.85)
            Button { vm.beginEdit(rule); addingRule = true } label: {
                HStack(spacing: 10) {
                    comboChip(rule.input.displayName)
                    Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(.secondary)
                    comboChip(rule.output.displayLabel)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Edit this mapping")
            Spacer()
            Button(role: .destructive) { vm.removeRule(rule) } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
    }

    // MARK: - Add-mapping sheet (record the key, then record-or-pick the output)

    private var captureSheet: some View {
        let editing = vm.editingRuleID != nil
        return VStack(spacing: 0) {
            // Header (matches the app's other dialogs)
            VStack(alignment: .leading, spacing: 2) {
                Text(editing ? "Edit mapping" : "Add mapping").font(.headline)
                Text("Press a key or shortcut, then choose what it does.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                fromColumn
                Image(systemName: "arrow.down").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center)
                toColumn
                if let input = vm.draftInput, vm.draftOutput != nil,
                   vm.rules.contains(where: { $0.input == input && $0.id != vm.editingRuleID }) {
                    Label("\(input.displayName) is already mapped.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { addingRule = false }.keyboardShortcut(.cancelAction)
                Button(editing ? "Save" : "Add") { vm.addDraft(); addingRule = false }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(!vm.canAddDraft)
            }
            .padding(16)
        }
        .frame(width: 540)
        .onAppear { if vm.editingRuleID == nil { vm.clearDraft(); vm.record(.input) } }   // add: auto-record · edit: keep prefill
        .sheet(isPresented: $picking) {
            ActionPicker(excluding: [.passThrough]) { kind in
                if kind.target == .none { vm.setOutputAction(Action(kind: kind)) }
                else { targetPrompt = kind }
            }
        }
        .sheet(item: $targetPrompt) { targetSheet($0) }
    }

    // FROM row: click the full-width box to record the key/shortcut you press (click again to cancel).
    private var fromColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel("FROM")
            Button { toggleRecord(.input) } label: {
                fieldBox(text: vm.recording == .input ? "Recording — press keys now" : (vm.draftInput?.displayName ?? "Click to record"),
                         active: vm.recording == .input, placeholder: vm.draftInput == nil && vm.recording != .input)
            }
            .buttonStyle(.plain)
            Text(vm.recording == .input ? "Press the key or shortcut you want to change."
                                        : "Click the box, then press a key or shortcut.")
                .font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
    }

    // TO row: a full-width record box + a compact icon-only "Pick action" button beside it.
    private var toColumn: some View {
        let active = vm.recording == .output
        return VStack(alignment: .leading, spacing: 7) {
            fieldLabel("TO")
            HStack(spacing: 8) {
                Button { toggleRecord(.output) } label: {
                    fieldBox(text: active ? "Recording — press keys now" : (vm.draftOutput?.displayLabel ?? "Click to record a key"),
                             active: active, placeholder: vm.draftOutput == nil && !active)
                }
                .buttonStyle(.plain)
                Button { vm.cancelRecording(); picking = true } label: {   // stop recording, then pick
                    Image(systemName: "square.grid.2x2").font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Pick a ready-made action")
            }
            Text(active ? "Press the key or shortcut it should become."
                        : "Click the box to record a key, or use the grid to pick an action.")
                .font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
    }

    /// Click a box to start recording; click it again (while recording) to cancel.
    private func toggleRecord(_ field: RemapField) {
        if vm.recording == field { vm.cancelRecording() } else { vm.record(field) }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
    }

    private func fieldBox(text: String, active: Bool, placeholder: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(placeholder ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity).frame(height: 52).padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(active ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: active ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if active {
                    Image(systemName: "circle.fill").font(.system(size: 8))
                        .foregroundStyle(.green).symbolEffect(.pulse).padding(8)
                }
            }
    }

    @ViewBuilder
    private func targetSheet(_ kind: ActionKind) -> some View {
        switch kind.target {
        case .app:
            AppPickerSheet(allowsMultipleSelection: false) { ids in if let b = ids.first { vm.setOutputAction(Action(kind: .openApp, target: b)) } }
        case .keystroke:
            KeystrokeCaptureSheet { code, mods in
                vm.setOutputAction(Action(kind: .customKeystroke, keyCode: Int(code), modifiers: mods))
            }
        case .url:
            TextTargetSheet(title: "Open URL", placeholder: "https://…") { vm.setOutputAction(Action(kind: .openURL, target: $0)) }
        case .file:
            TextTargetSheet(title: "Open File or Folder", placeholder: "/Users/…/file", allowFilePicker: true) { vm.setOutputAction(Action(kind: .openFile, target: $0)) }
        case .shellScript:
            PresetPickerSheet(title: "Run Shell Script", customPlaceholder: "echo hello", load: { ActionPresets.shell }) { vm.setOutputAction(Action(kind: .runShell, target: $0)) }
        case .appleScript:
            PresetPickerSheet(title: "Run AppleScript", customPlaceholder: "display dialog \"Hi\"", load: { ActionPresets.appleScript }) { vm.setOutputAction(Action(kind: .runAppleScript, target: $0)) }
        default:
            EmptyView()
        }
    }

    private func comboChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }
}
