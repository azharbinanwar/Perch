//
//  ClipboardShortcutsOverlay.swift
//  Perch
//
//  The clipboard's keyboard-shortcuts card, shown as a centered overlay (dimmed backdrop,
//  tap to dismiss). Reused by the ⌘⇧V popup and the Clipboard settings tab so both match.
//  Other modules get their own shortcuts overlay.
//

import SwiftUI

struct ClipboardShortcutsOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard Shortcuts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ShortcutColumns()
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
        }
    }
}
