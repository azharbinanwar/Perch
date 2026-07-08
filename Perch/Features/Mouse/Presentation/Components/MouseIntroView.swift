//
//  MouseIntroView.swift
//  Perch
//
//  Self-contained mouse showcase: the animated MouseDemoStage plus its running caption.
//  Embeddable anywhere (the permission gate's intro slot, or a standalone intro sheet).
//

import SwiftUI

struct MouseIntroView: View {
    @State private var caption = "Turn any mouse into a productivity device."

    var body: some View {
        VStack(spacing: 12) {
            MouseDemoStage(caption: $caption, showDots: true)
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
