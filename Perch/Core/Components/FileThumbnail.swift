//
//  FileThumbnail.swift
//  Perch
//
//  A file's small thumbnail (image/PDF/doc…), decoded at display size and cached, with the
//  system file icon as a placeholder until it's ready. Light enough for long lists.
//

import SwiftUI

struct FileThumbnail: View {
    let path: String
    var size: CGFloat = 16
    var fill: Bool = true   // true = crop-to-fill the box (tiles/icons); false = fit

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                if fill {
                    // Fill-and-crop to whatever box the caller gives us — never overflow it.
                    Color.clear.overlay(
                        Image(nsImage: thumbnail).resizable().scaledToFill()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(nsImage: thumbnail).resizable().scaledToFit()
                }
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable().scaledToFit()   // placeholder while the thumbnail loads
            }
        }
        .task(id: path) { thumbnail = await Thumbnailer.thumbnail(path, size: size) }
    }
}
