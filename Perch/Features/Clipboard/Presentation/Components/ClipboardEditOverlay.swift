//
//  ClipboardEditOverlay.swift
//  Perch
//
//  Edit-before-paste: a focused text editor over the popup. ⌘⏎ pastes the edited text into
//  the target app (the stored clip is untouched); Esc cancels back to the list.
//

import SwiftUI

struct ClipboardEditOverlay: View {
    @Binding var text: String
    let onPaste: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 10) {
                Text("Edit & Paste")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    .focused($focused)

                HStack {
                    Text("⌘⏎ paste · esc cancel")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                    Button("Paste", action: onPaste)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
            .padding(14)
        }
        .onAppear { focused = true }
    }
}
