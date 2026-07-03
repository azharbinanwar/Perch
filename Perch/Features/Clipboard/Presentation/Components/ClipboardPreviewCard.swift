//
//  ClipboardPreviewCard.swift
//  Perch
//
//  Full-content preview of a clipboard item (Quick-Look style): source app + time
//  header, then the whole text, scrollable and selectable.
//

import SwiftUI

struct ClipboardPreviewCard: View {
    let item: ClipboardItem
    @Binding var index: Int          // carousel position, driven by ← →
    let onDismiss: () -> Void

    private var filePaths: [String] { item.filePaths ?? [] }
    private var filesAreImages: Bool { !filePaths.isEmpty && filePaths.allSatisfy(Thumbnailer.isImage) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 10) {
                header
                Divider()
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill the popup, never overflow it
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
            .padding(14)                                          // margin from the window edges
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .image:
            let names = item.imageFiles ?? []
            if names.isEmpty {
                unavailable("Image unavailable")
            } else {
                ImageCarousel(paths: names.map(ImageStore.path), index: $index)   // 1 = fit, many = carousel
            }
        case .files:
            if filesAreImages {
                ImageCarousel(paths: filePaths, index: $index)     // one image = fit; many = carousel
            } else if filePaths.count == 1 {
                FileThumbnail(path: filePaths[0], size: 512, fill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fileList
            }
        case .text:
            ScrollView {
                Text(item.text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 14)], spacing: 14) {
                ForEach(filePaths, id: \.self) { path in
                    VStack(spacing: 6) {
                        FileThumbnail(path: path, size: 180)
                            .frame(width: 96, height: 96)            // square, cropped-to-fill
                            .background(.quaternary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text((path as NSString).lastPathComponent)
                            .font(.system(size: 11))
                            .lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(2)
        }
    }

    private func unavailable(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = AppIcon.forBundleID(item.sourceApp) {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(AppIcon.name(forBundleID: item.sourceApp) ?? "Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                if let detail {
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            if let badge = countBadge {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Spacer()
            Text(item.copiedAt, format: .relative(presentation: .named))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    /// Size/count metrics: text → chars·words, image → bytes, files → count·bytes.
    private var detail: String? {
        switch item.content {
        case .text:
            let chars = item.text.count
            let words = item.text.split { $0.isWhitespace || $0.isNewline }.count
            return "\(chars) character\(chars == 1 ? "" : "s") · \(words) word\(words == 1 ? "" : "s")"
        case .image:
            let bytes = (item.imageFiles ?? []).reduce(0) { $0 + fileSize(ImageStore.path($1)) }
            return bytes > 0 ? byteText(bytes) : nil
        case .files:
            let bytes = filePaths.reduce(0) { $0 + fileSize($1) }
            let size = bytes > 0 ? " · \(byteText(bytes))" : ""
            return "\(filePaths.count) file\(filePaths.count == 1 ? "" : "s")\(size)"
        }
    }

    private func fileSize(_ path: String) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int ?? 0
    }

    private func byteText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// "N images" / "N files" chip in the header — also a quick confirmation of the content type.
    private var countBadge: String? {
        switch item.content {
        case .image:
            let n = item.imageFiles?.count ?? 0
            return n > 1 ? "\(n) images" : nil
        case .files:
            let n = filePaths.count
            guard n > 1 else { return nil }
            return "\(n) \(filesAreImages ? "images" : "files")"
        case .text:
            return nil
        }
    }
}
