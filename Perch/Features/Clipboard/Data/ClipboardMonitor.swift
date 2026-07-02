//
//  ClipboardMonitor.swift
//  Perch
//
//  Manager. macOS has no copy-notification API, so we poll NSPasteboard.changeCount.
//  Registered in ServiceLocator; owned (via resolve) by ClipboardViewModel.
//

import AppKit

/// One captured copy: plain text (always) + source app + optional rich representation.
struct CapturedCopy {
    let text: String
    let source: String?
    let richData: Data?
    let richType: String?
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
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let rich = richContent()
        onCopy?(CapturedCopy(text: text, source: source, richData: rich?.data, richType: rich?.type))
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
