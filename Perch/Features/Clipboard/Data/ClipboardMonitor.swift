//
//  ClipboardMonitor.swift
//  Perch
//
//  Manager. macOS has no copy-notification API, so we poll NSPasteboard.changeCount.
//  Registered in ServiceLocator; owned (via resolve) by ClipboardViewModel.
//

import AppKit

/// One captured copy: text / image / files, + source app.
struct CapturedCopy {
    let text: String
    let source: String?
    var richData: Data? = nil
    var richType: String? = nil
    var imageDatas: [Data]? = nil    // PNGs, when one or more images were copied together
    var filePaths: [String]? = nil   // when files were copied
}

final class ClipboardMonitor {
    var onCopy: ((CapturedCopy) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: AppConfig.clipboardPollInterval,
                                     repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call after we write to the pasteboard ourselves, so we don't re-capture our own write.
    func syncChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if isSensitive { return }   // skip passwords / transient copies
        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // 1) files (references — cheap, no data copied)
        if let paths = filePaths(), !paths.isEmpty {
            let names = paths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
            onCopy?(CapturedCopy(text: names, source: source, filePaths: paths))
            return
        }
        // 2) text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let rich = richContent()
            onCopy?(CapturedCopy(text: text, source: source, richData: rich?.data, richType: rich?.type))
            return
        }
        // 3) images (bytes we must keep ourselves) — one copy may carry several
        let pngs = images()
        if !pngs.isEmpty {
            let label = pngs.count > 1 ? "\(pngs.count) images" : "Image"
            onCopy?(CapturedCopy(text: label, source: source, imageDatas: pngs))
        }
    }

    private func filePaths() -> [String]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return nil
        }
        return urls.map(\.path)
    }

    /// PNG data for every copied image (a full-screen copy on two displays yields two).
    /// Skips any image over the size cap.
    private func images() -> [Data] {
        guard let objects = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] else {
            return []
        }
        return objects.compactMap { image in
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]),
                  png.count <= 10_000_000 else { return nil }   // cap ~10 MB
            return png
        }
    }

    /// The richest formatted representation the copy offers (RTF → RTFD → HTML), if any.
    private func richContent() -> (data: Data, type: String)? {
        let candidates: [NSPasteboard.PasteboardType] = [.rtf, .init("com.apple.flat-rtfd"), .html]
        for type in candidates {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return (data, type.rawValue)
            }
        }
        return nil
    }

    /// True when the source app marked the copy as concealed/transient/sensitive
    /// (password managers, Apple autofill). We don't record those.
    private var isSensitive: Bool {
        guard let types = pasteboard.types else { return false }
        return types.contains { Self.sensitiveTypes.contains($0) }
    }

    private static let sensitiveTypes: Set<NSPasteboard.PasteboardType> = [
        .init("org.nspasteboard.ConcealedType"),
        .init("org.nspasteboard.TransientType"),
        .init("com.apple.is-sensitive"),
    ]
}
