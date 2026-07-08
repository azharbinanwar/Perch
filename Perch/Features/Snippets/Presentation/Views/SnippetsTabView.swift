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
                        title: "Accessibility needed",
                        message: "Grant Accessibility to expand snippets as you type. Your snippets stay saved in the clipboard either way.",
                        onGrant: { AccessibilityService.shared.request() },
                        onShowIntro: { showingShowcase = true })
                        .padding(.horizontal, 20).padding(.bottom, 12)
                }
                // Master: interactive only when Accessibility is on; dimmed (not hidden) when off.
                masterGroup
                    .disabled(!trusted)
                    .opacity(trusted ? 1 : 0.5)
                // List: dimmed (not hidden) when Accessibility is off or expansion is off.
                Group {
                    if vm.snippets.isEmpty { emptyState } else { listContent }
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
            Button("Clear All", role: .destructive) { vm.clearAll() }
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

    // MARK: - Master

    private var masterGroup: some View {
        GroupBox {
            SettingRow(title: "Enable Snippets",
                       subtitle: vm.expansionEnabled ? "Type an abbreviation in any app and it expands."
                                                     : "Off — snippets are still available in the clipboard.") {
                Toggle("", isOn: Binding(get: { vm.expansionEnabled }, set: { vm.setExpansionEnabled($0) }))
                    .toggleStyle(.switch).labelsHidden()
            }
            .padding(6)
        }
        .padding(.horizontal, 20)
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

    // Rows only — the page-level ScrollView does the scrolling (no nested ScrollView).
    private var listContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(vm.snippets.enumerated()), id: \.element.id) { index, snippet in
                if index > 0 { Divider() }
                row(snippet)
            }
        }
        .padding(8)
    }

    private func row(_ snippet: Snippet) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text").foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snippet.name).font(.system(size: 13, weight: .medium))
                    if vm.expansionEnabled, let abbreviation = snippet.abbreviation {
                        Text("\(vm.expansionPrefix.rawValue)\(abbreviation)\(vm.expansionPrefix.rawValue)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                    }
                }
                Text(snippet.text).lineLimit(2).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { editing = snippet } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
            Button(role: .destructive) { vm.delete(snippet) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture { editing = snippet }   // whole row opens the snippet
    }
}
