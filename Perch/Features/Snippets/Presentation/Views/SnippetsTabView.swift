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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.snippets.isEmpty { emptyState } else { list }
        }
        .sheet(item: $editing) { snippet in
            SnippetEditor(snippet: snippet) { vm.upsert($0) }
        }
        .sheet(isPresented: $showingNew) {
            SnippetEditor(snippet: nil) { vm.upsert($0) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Snippets").font(.title2.bold())
                Text("Saved clips you reuse — always available in the clipboard.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showingNew = true } label: { Label("New", systemImage: "plus") }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            LazyVStack(spacing: 2) {
                ForEach(vm.snippets) { snippet in
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
                Text(snippet.name).font(.system(size: 13, weight: .medium))
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
