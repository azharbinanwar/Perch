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
            Button { showingIntro = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 15))
                    .frame(height: 16)   // match the text buttons' control height
            }
            .help("See how snippets work")
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(height: 16)   // match the text buttons' control height
            }
            .help("Text expansion settings")
            Button(role: .destructive) { showingClearAll = true } label: {
                Label("Clear All", systemImage: "trash")
            }
            .disabled(vm.snippets.isEmpty)
            Button { showingNew = true } label: { Label("New", systemImage: "plus") }
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
