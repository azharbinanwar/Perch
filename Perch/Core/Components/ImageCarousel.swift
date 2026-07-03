//
//  ImageCarousel.swift
//  Perch
//
//  Fit-to-space image viewer. With more than one path it becomes a carousel: ‹ › arrows
//  and an "n / total" counter. The current image loads on demand (high quality, capped
//  cache) and always fits the available space — no zoom, no overflow.
//

import SwiftUI

struct ImageCarousel: View {
    let paths: [String]
    @Binding var index: Int

    @State private var image: NSImage?

    private var currentPath: String? { paths.indices.contains(index) ? paths[index] : nil }

    var body: some View {
        VStack(spacing: 10) {
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()   // never spill past the box, on either axis

            if paths.count > 1 {
                HStack(spacing: 16) {
                    arrow("chevron.left") { step(-1) }
                    Text("\(index + 1) / \(paths.count)")
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary)
                    arrow("chevron.right") { step(1) }
                }
            }
        }
        .onChange(of: paths) { index = 0 }               // reset when shown for a different item
        .task(id: currentPath) {
            guard let path = currentPath else { image = nil; return }
            let loaded = await Thumbnailer.fullImage(path)
            withAnimation(.easeInOut(duration: 0.2)) { image = loaded }
        }
    }

    @ViewBuilder
    private var page: some View {
        if let image {
            Image(nsImage: image)
                .resizable().scaledToFit()   // fit width AND height, never larger than the frame
                .id(index)                   // new identity per page → slide transition
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
        } else {
            Color.clear   // brief placeholder while the image loads
        }
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func step(_ delta: Int) {
        guard !paths.isEmpty else { return }
        index = (index + delta + paths.count) % paths.count   // wraps
    }
}
