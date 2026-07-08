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
    @State private var profileIntroShowing = false // per-app profiles, in keys language
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
                // Just a setting — inlined, not its own component.
                SettingGroup("Keyboard") {
                    SettingRow(title: "Enable Keys",
                               subtitle: "Master switch — key remapping, Hyper Key, and double-tap. Applies to all keyboards.",
                               icon: "keyboard") {
                        Toggle("", isOn: Binding(get: { vm.isEnabled }, set: { _ in vm.toggleEnabled() }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                .disabled(!trusted)
                .opacity(trusted ? 1 : 0.5)
                // Profile strip on top, like Mouse — it governs the per-app section below.
                SettingGroup {
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
                .opacity(moduleActive ? 1 : 0.5)
                ShortcutsGroup(onEdit: { rule in vm.beginEdit(rule); addingRule = true })
                HyperKeyGroup()
                DoubleTapGroup()
            }
            .padding(20)
        }
        .sheet(isPresented: $showingKeysIntro) {
            ShowcaseSheet(title: "Keys", content: AnyView(KeysIntroView()))
        }
        .onAppear { AccessibilityService.shared.refresh() }
        .sheet(isPresented: $profileIntroShowing) { KeysProfileIntroSheet() }
        .sheet(isPresented: $addingRule, onDismiss: { vm.clearDraft() }) { MappingCaptureSheet() }
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


}
