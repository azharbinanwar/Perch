//
//  SnippetEditor.swift
//  Perch
//
//  Sheet to create or edit a snippet (name + text).
//

import SwiftUI

struct SnippetEditor: View {
    let existing: Snippet?
    let onSave: (Snippet) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var text: String

    init(snippet: Snippet?, onSave: @escaping (Snippet) -> Void) {
        self.existing = snippet
        self.onSave = onSave
        _name = State(initialValue: snippet?.name ?? "")
        _text = State(initialValue: snippet?.text ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "New Snippet" : "Edit Snippet").font(.headline)

            TextField("Name (e.g. Email)", text: $name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(height: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || text.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 400)
    }

    private func save() {
        onSave(Snippet(id: existing?.id ?? UUID(),
                       name: name.trimmingCharacters(in: .whitespaces),
                       text: text))
        dismiss()
    }
}
