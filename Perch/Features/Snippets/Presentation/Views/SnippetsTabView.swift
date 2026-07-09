//
//  SnippetsTabView.swift
//  Perch
//
//  Manage snippets: create, edit, delete named reusable clips.
//

import SwiftUI

struct SnippetsTabView: View {
    @Environment(SnippetViewModel.self) private var vm

    @State private var editing: Snippet?
    @State private var showingNew = false
    @State private var showingClearAll = false
    @State private var showingIntro = false
    @State private var showingSettings = false
    @State private var showingShowcase = false   // "What you get" showcase sheet
    // Reactive read — when the grant flips (watcher/activation), the tile + dimming auto-update.
    private var trusted: Bool { AccessibilityService.shared.isTrusted }
    /// The list is live only when Accessibility is granted AND expansion (the master) is on.
    private var moduleActive: Bool { trusted && vm.expansionEnabled }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                // Tile appears only when Accessibility is off (nothing else is ever hidden).
                if !trusted {
                    PermissionTile(
                        icon: "text.quote",
                        title: "Accessibility needed",
                        message: "Grant Accessibility to expand snippets as you type. Your snippets stay saved in the clipboard either way.",
                        onGrant: { AccessibilityService.shared.request() },
                        onShowIntro: { showingShowcase = true })
                        .padding(.horizontal, 20).padding(.bottom, 12)
                }
                // Master: interactive only when Accessibility is on; dimmed (not hidden) when off.
                SettingGroup {
                    SettingRow(title: "Enable Snippets",
                               subtitle: vm.expansionEnabled ? "Type an abbreviation in any app and it expands."
                                                             : "Off — snippets are still available in the clipboard.",
                               icon: "text.quote") {
                        SwitchToggle(isOn: vm.expansionEnabled) { vm.setExpansionEnabled($0) }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .disabled(!trusted)
                .opacity(trusted ? 1 : 0.5)
                // List: dimmed (not hidden) when Accessibility is off or expansion is off.
                Group {
                    if vm.snippets.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(vm.snippets.enumerated()), id: \.element.id) { index, snippet in
                                if index > 0 { Divider() }
                                SnippetRow(snippet: snippet) { editing = snippet }
                            }
                        }
                        .padding(8)
                    }
                }
                .opacity(moduleActive ? 1 : 0.5)
                .disabled(!moduleActive)
            }
        }
        .onAppear { AccessibilityService.shared.refresh() }
        .sheet(isPresented: $showingShowcase) {
            ShowcaseSheet(title: "Snippets", content: AnyView(SnippetIntroView()))
        }
        .sheet(item: $editing) { snippet in
            SnippetEditor(snippet: snippet, prefix: vm.expansionPrefix.rawValue,
                          taken: vm.takenAbbreviations(excluding: snippet.id)) { vm.upsert($0) }
        }
        .sheet(isPresented: $showingNew) {
            SnippetEditor(snippet: nil, prefix: vm.expansionPrefix.rawValue,
                          taken: vm.takenAbbreviations(excluding: nil)) { vm.upsert($0) }
        }
        .sheet(isPresented: $showingIntro) { SnippetIntroSheet() }
        .sheet(isPresented: $showingSettings) { SnippetSettingsSheet() }
        .alert("Clear all snippets?", isPresented: $showingClearAll) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { vm.clearAll() }
        } message: {
            Text("This permanently deletes all \(vm.snippets.count) saved snippets. This can't be undone.")
        }
    }

    private var header: some View {
        HStack {
            PageHeader("Snippets", subtitle: "Saved clips you reuse — always available in the clipboard.")
            Spacer()
            HeaderIconButton(icon: "info.circle", help: "See how snippets work") {
                showingIntro = true
            }
            // Config/destructive actions are disabled (not hidden) until Accessibility is granted.
            HeaderIconButton(icon: "gearshape", help: "Text expansion settings") {
                showingSettings = true
            }
            .disabled(!trusted)
            HeaderIconButton(icon: "trash", help: "Delete all snippets", destructive: true) {
                showingClearAll = true
            }
            .disabled(vm.snippets.isEmpty || !trusted)
            HeaderIconButton(icon: "plus", help: "New snippet") {
                showingNew = true
            }
            .disabled(!trusted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Snippets", systemImage: "text.badge.plus")
        } description: {
            Text("Save texts you paste often — your email, address, replies.")
        } actions: {
            Button("New Snippet") { showingNew = true }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}
