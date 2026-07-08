//
//  SnippetIntroView.swift
//  Perch
//
//  Self-contained snippets showcase: the animated SnippetDemoStage plus its running caption.
//  Embeddable anywhere (the permission gate's intro slot, or a standalone intro sheet).
//

import SwiftUI

struct SnippetIntroView: View {
    @State private var caption = "Type a short abbreviation — it becomes the full text."

    var body: some View {
        VStack(spacing: 12) {
            SnippetDemoStage(caption: $caption, showDots: true)
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
