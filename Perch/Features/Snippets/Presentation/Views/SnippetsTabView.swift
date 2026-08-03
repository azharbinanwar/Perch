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
                Divider().padding(.bottom, 20)   // match the 20pt content inset of the other tabs
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
        .navigationTitle("Snippets")
        .navigationSubtitle(snippetSubtitle)
        // Native toolbar: icon-only buttons get the system's glassy material for free.
        .toolbar {
            // Learn/configure cluster.
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingIntro = true } label: {
                    Label("How snippets work", systemImage: "info.circle")
                }
                .help("See how snippets work")
                Button { showingSettings = true } label: {
                    Label("Expansion settings", systemImage: "gearshape")
                }
                .help("Text expansion settings")
                .disabled(!trusted)
            }
            // Content-action cluster: destructive + create, plus rightmost. On macOS 26 the
            // spacer splits the Liquid Glass capsule; earlier systems space buttons anyway.
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(role: .destructive) { showingClearAll = true } label: {
                    Label("Delete all snippets", systemImage: "trash")
                }
                .help("Delete all snippets")
                .disabled(vm.snippets.isEmpty || !trusted)
                Button { showingNew = true } label: {
                    Label("New snippet", systemImage: "plus")
                }
                .help("New snippet")
                .disabled(!trusted)
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

    /// "N snippets · expansion on" — or an honest empty state.
    private var snippetSubtitle: String {
        guard !vm.snippets.isEmpty else { return "No snippets yet" }
        let count = "\(vm.snippets.count) snippet\(vm.snippets.count == 1 ? "" : "s")"
        return "\(count) · expansion \(moduleActive ? "on" : "off")"
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
