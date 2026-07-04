//
//  PresetPickerSheet.swift
//  Perch
//
//  Reusable "pick a ready-made preset, or write your own" list. Same chrome as the other pickers.
//  Fed a title + a loader for the list + an onPick — no per-type logic lives here.
//

import SwiftUI

struct PresetPickerSheet: View {
    let title: String
    var customPlaceholder: String = ""
    var emptyMessage: String = "Nothing here yet."
    let load: () async -> [ActionPreset]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var presets: [ActionPreset] = []
    @State private var loaded = false
    @State private var search = ""
    @State private var customMode = false
    @State private var custom = ""

    private var filtered: [ActionPreset] {
        guard !search.isEmpty else { return presets }
        return presets.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(customMode ? "Custom — \(title)" : title).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            if customMode { customEntry } else { picker }
        }
        .frame(width: 540, height: 480)
        .onExitCommand { dismiss() }
        .task { presets = await load(); loaded = true }
    }

    // MARK: - Preset list

    private var picker: some View {
        VStack(spacing: 0) {
            SearchField(placeholder: "Search", text: $search, autofocus: true)
                .padding(.horizontal, 16).padding(.bottom, 8)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !loaded {
                        ProgressView().padding(.vertical, 34)
                    } else if filtered.isEmpty {
                        Text(search.isEmpty ? emptyMessage : "No matches.")
                            .font(.system(size: 12)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            .padding(.horizontal, 24).padding(.vertical, 34)
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, p in
                            if i > 0 { Divider() }
                            row(p.name, p.detail, icon: "bolt.circle") { onPick(p.value); dismiss() }
                        }
                    }
                    Divider()
                    row("Custom…", "Write your own", icon: "pencil.circle") { custom = ""; customMode = true }
                }
                .padding(8)
            }
        }
    }

    private func row(_ name: String, _ detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).frame(width: 20).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom entry

    private var customEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(customPlaceholder, text: $custom, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...12)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 16).padding(.top, 8)
            Spacer()
            HStack {
                Button("Back") { customMode = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onPick(custom); dismiss() }
                    .keyboardShortcut(.defaultAction).disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }
}
