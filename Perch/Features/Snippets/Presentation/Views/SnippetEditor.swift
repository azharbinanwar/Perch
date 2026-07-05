//
//  SnippetEditor.swift
//  Perch
//
//  Sheet to create or edit a snippet (name + text).
//

import SwiftUI

struct SnippetEditor: View {
    let existing: Snippet?
    var prefix = ";"
    var taken: Set<String> = []   // abbreviations used by OTHER snippets (uniqueness check)
    let onSave: (Snippet) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var text: String
    @State private var abbreviation: String

    init(snippet: Snippet?, prefix: String = ";", taken: Set<String> = [], onSave: @escaping (Snippet) -> Void) {
        self.existing = snippet
        self.prefix = prefix
        self.taken = taken
        self.onSave = onSave
        _name = State(initialValue: snippet?.name ?? "")
        _text = State(initialValue: snippet?.text ?? "")
        _abbreviation = State(initialValue: snippet?.abbreviation ?? "")
    }

    private var cleanAbbreviation: String {
        abbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isConflict: Bool { !cleanAbbreviation.isEmpty && taken.contains(cleanAbbreviation) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "New Snippet" : "Edit Snippet").font(.headline)

            TextField("Name (e.g. Email)", text: $name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Abbreviation").font(.system(size: 12, weight: .medium))
                    Text("optional").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Text(prefix)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("addr", text: $abbreviation)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 140)
                }
                if isConflict {
                    Text("\(prefix)\(cleanAbbreviation) is already used by another snippet.")
                        .font(.system(size: 11)).foregroundStyle(.red)
                } else {
                    Text(cleanAbbreviation.isEmpty
                         ? "Add one to type this snippet anywhere — e.g. type \(prefix)addr and it expands instantly."
                         : "Type \(prefix)\(cleanAbbreviation) in any app and it becomes this snippet.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || text.isEmpty || isConflict)
            }
        }
        .padding(16)
        .frame(width: 540, height: 480)   // match the app/action picker sheets
    }

    private func save() {
        onSave(Snippet(id: existing?.id ?? UUID(),
                       name: name.trimmingCharacters(in: .whitespaces),
                       text: text,
                       abbreviation: cleanAbbreviation.isEmpty ? nil : cleanAbbreviation))
        dismiss()
    }
}
