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

    var body: some View {
        VStack(spacing: 0) {
            header
            if vm.snippets.isEmpty { emptyState } else { list }
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
            HeaderIconButton(icon: "gearshape", help: "Text expansion settings") {
                showingSettings = true
            }
            HeaderIconButton(icon: "trash", help: "Delete all snippets", destructive: true) {
                showingClearAll = true
            }
            .disabled(vm.snippets.isEmpty)
            HeaderIconButton(icon: "plus", help: "New snippet") {
                showingNew = true
            }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.snippets.enumerated()), id: \.element.id) { index, snippet in
                    if index > 0 { Divider() }
                    row(snippet)
                }
            }
            .padding(8)
        }
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
