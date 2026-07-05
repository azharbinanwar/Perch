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

    var body: some View {
        VStack(spacing: 0) {
            header
            expansionGroup
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
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

    // MARK: - Text expansion

    private var expansionGroup: some View {
        GroupBox("Text Expansion") {
            VStack(spacing: 10) {
                SettingRow(title: "Expand abbreviations as you type",
                           subtitle: "Type a snippet's abbreviation (like \(vm.expansionPrefix.rawValue)addr) in any app and it becomes the full text instantly.") {
                    Toggle("", isOn: Binding(get: { vm.expansionEnabled }, set: { vm.setExpansionEnabled($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
                if vm.expansionEnabled {
                    Divider()
                    SettingRow(title: "Trigger prefix",
                               subtitle: "Starts every abbreviation, so normal typing never expands by accident.") {
                        Picker("", selection: Binding(get: { vm.expansionPrefix }, set: { vm.setExpansionPrefix($0) })) {
                            ForEach(ExpansionPrefix.allCases) { prefix in
                                Text(prefix.rawValue).font(.system(.body, design: .monospaced)).tag(prefix)
                            }
                        }
                        .labelsHidden().frame(width: 80)
                    }
                }
            }
            .padding(6)
        }
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
                        Text("\(vm.expansionPrefix.rawValue)\(abbreviation)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                    }
                }
                Text(snippet.text).lineLimit(1).font(.system(size: 11)).foregroundStyle(.secondary)
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
        .onTapGesture(count: 2) { editing = snippet }
    }
}
