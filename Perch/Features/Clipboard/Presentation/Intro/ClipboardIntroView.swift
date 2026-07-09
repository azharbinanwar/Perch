//
//  ClipboardIntroView.swift
//  Perch
//
//  Self-contained clipboard showcase: the animated ClipboardDemoStage plus its running caption.
//  Embeddable anywhere (the permission gate's intro slot, or a standalone intro sheet).
//

import SwiftUI

struct ClipboardIntroView: View {
    @State private var caption = "Everything you copy, one shortcut away."

    var body: some View {
        VStack(spacing: 12) {
            ClipboardDemoStage(caption: $caption, showDots: true)
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
