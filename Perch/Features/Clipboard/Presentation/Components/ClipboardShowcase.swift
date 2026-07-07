//
//  ClipboardShowcase.swift
//  Perch
//
//  The "see what you'll unlock" view shown from the Accessibility gate. It reuses the SAME
//  ClipboardDemoStage as the in-app intro, wrapped in a frosted frame with the running
//  caption and a Grant call-to-action — so watching the tour flows straight into enabling it.
//

import SwiftUI

struct ClipboardShowcase: View {
    var onClose: () -> Void = {}
    var onGrant: () -> Void = { AccessibilityService.shared.request() }

    @State private var caption = "Everything you copy, one shortcut away."

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 18) {
                Text("Your clipboard, supercharged")
                    .font(.system(size: 17, weight: .semibold))

                ClipboardDemoStage(caption: $caption, showDots: true)

                Text(caption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: 380)
                    .animation(.easeOut(duration: 0.2), value: caption)

                Button(action: onGrant) {
                    Text("Grant Accessibility")
                        .font(.system(size: 12.5, weight: .semibold))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18)).foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Back")
            .padding(12)
        }
        .background(.ultraThinMaterial)
    }
}
