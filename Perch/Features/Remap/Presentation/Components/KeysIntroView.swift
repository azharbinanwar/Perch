//
//  KeysIntroView.swift
//  Perch
//
//  Self-contained keys showcase: the animated KeysDemoStage plus its running caption.
//  Embeddable anywhere (the permission gate's intro slot, or a standalone intro sheet).
//

import SwiftUI

struct KeysIntroView: View {
    @State private var caption = "Remap keys and shortcuts, app by app."

    var body: some View {
        VStack(spacing: 12) {
            KeysDemoStage(caption: $caption, showDots: true)
            Text(caption)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: 380)
                .animation(.easeOut(duration: 0.2), value: caption)
        }
    }
}
