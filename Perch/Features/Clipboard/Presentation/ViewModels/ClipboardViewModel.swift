//
//  ClipboardViewModel.swift
//  Perch
//

import AppKit
import Observation

@Observable
final class ClipboardViewModel {
    private(set) var state: ClipboardState = .empty
    private(set) var isEnabled: Bool      // master — clipboard feature available at all
    private(set) var isRecording: Bool    // capture new copies (only while enabled)
    private(set) var autoClearMinutes: Int  // drop items older than this; 0 = never
    private(set) var maxItems: Int          // history cap (unpinned items)
    private(set) var clearOnQuit: Bool      // wipe history when the app quits
    private(set) var pinLimit: Int          // max number of pinned items
    private(set) var rowDensity: RowDensity // popup row size
    private(set) var excludedRecordApps: [String]  // bundle ids we don't record copies from
    private(set) var excludedOpenApps: [String]     // bundle ids where ⌘⇧V won't open
    private(set) var restoreAfterPaste: Bool        // put the old clipboard back after pasting
    private(set) var screenshotsToClipboard: Bool   // auto-capture new screenshot files
    private(set) var screenshotFolderOverride: String?  // nil = follow the OS screenshot location

    /// The folder currently watched — the override, else the OS location, else ~/Desktop.
    var screenshotFolder: String { ScreenshotWatcher.resolvedFolder(override: screenshotFolderOverride) }

    private var savedClipboard: [(data: Data, type: NSPasteboard.PasteboardType)]?

    private let repository: ClipboardRepository
    private let monitor: ClipboardMonitor
    private let screenshotWatcher: ScreenshotWatcher
    private let pasteboard = NSPasteboard.general
    private let defaults = UserDefaults.standard

    private var items: [ClipboardItem] = [] {
        didSet { state = items.isEmpty ? .empty : .loaded(orderedItems) }
    }

    /// Pinned items float to the top; the rest stay in recency order.
    private var orderedItems: [ClipboardItem] {
        items.filter(\.isPinned) + items.filter { !$0.isPinned }
    }

    var pinnedCount: Int { items.filter(\.isPinned).count }
    func isPinned(_ id: UUID) -> Bool { items.first { $0.id == id }?.isPinned ?? false }

    /// Recency order (newest first), ignoring pins — the menu peek uses this so pins
    /// don't crowd out recent copies.
    var recentItems: [ClipboardItem] { items }

    init(repository: ClipboardRepository = ServiceLocator.shared.resolve(ClipboardRepository.self),
         monitor: ClipboardMonitor = ServiceLocator.shared.resolve(ClipboardMonitor.self),
         screenshotWatcher: ScreenshotWatcher = ServiceLocator.shared.resolve(ScreenshotWatcher.self)) {
        self.repository = repository
        self.monitor = monitor
        self.screenshotWatcher = screenshotWatcher
        self.isEnabled = defaults.object(forKey: Keys.Defaults.clipboardEnabled) as? Bool ?? true
        self.isRecording = defaults.object(forKey: Keys.Defaults.clipboardRecording) as? Bool ?? true
        self.autoClearMinutes = defaults.object(forKey: Keys.Defaults.clipboardAutoClear) as? Int ?? 0
        self.maxItems = defaults.object(forKey: Keys.Defaults.clipboardMaxItems) as? Int ?? AppConfig.clipboardHistoryLimit
        self.clearOnQuit = defaults.object(forKey: Keys.Defaults.clipboardClearOnQuit) as? Bool ?? false
        self.pinLimit = defaults.object(forKey: Keys.Defaults.clipboardPinLimit) as? Int ?? 5
        self.rowDensity = RowDensity(rawValue: defaults.string(forKey: Keys.Defaults.clipboardRowDensity) ?? "") ?? .regular
        self.excludedRecordApps = defaults.stringArray(forKey: Keys.Defaults.clipboardExcludeRecord) ?? []
        self.excludedOpenApps = defaults.stringArray(forKey: Keys.Defaults.clipboardExcludeOpen) ?? []
        self.restoreAfterPaste = defaults.bool(forKey: Keys.Defaults.clipboardRestoreAfterPaste)
        self.screenshotsToClipboard = defaults.bool(forKey: Keys.Defaults.clipboardScreenshots)
        self.screenshotFolderOverride = defaults.string(forKey: Keys.Defaults.clipboardScreenshotFolder)
        self.items = repository.load()
        state = items.isEmpty ? .empty : .loaded(orderedItems)   // pinned-first, matching didSet
        ImageStore.pruneOrphans(keeping: referencedBlobs)   // drop blobs left over from a crash
    }

    /// Every image blob still referenced by a saved item.
    private var referencedBlobs: Set<String> {
        Set(items.compactMap(\.imageFiles).flatMap { $0 })
    }

    /// Begin watching the pasteboard. Called once from AppDelegate.
    func start() {
        monitor.onCopy = { [weak self] copy in
            self?.capture(copy)
        }
        screenshotWatcher.onScreenshot = { [weak self] png in
            self?.capture(CapturedCopy(text: "Screenshot", source: nil, imageDatas: [png]))
        }
        screenshotWatcher.onRecording = { [weak self] path in
            let name = (path as NSString).lastPathComponent
            self?.capture(CapturedCopy(text: name, source: nil, filePaths: [path]))
        }
        updateMonitor()
        updateScreenshotWatcher()
        pruneExpired()
    }

    /// Re-resolve the folder and start/stop the watcher — called on toggle, launch, and app-active
    /// (so a changed OS screenshot location is picked up).
    func updateScreenshotWatcher() {
        if screenshotsToClipboard && isEnabled {
            screenshotWatcher.start(folder: screenshotFolder)
        } else {
            screenshotWatcher.stop()
        }
    }

    func setScreenshotsToClipboard(_ on: Bool) {
        screenshotsToClipboard = on
        defaults.set(on, forKey: Keys.Defaults.clipboardScreenshots)
        updateScreenshotWatcher()
    }

    func setScreenshotFolder(_ path: String?) {
        screenshotFolderOverride = path
        if let path { defaults.set(path, forKey: Keys.Defaults.clipboardScreenshotFolder) }
        else { defaults.removeObject(forKey: Keys.Defaults.clipboardScreenshotFolder) }
        updateScreenshotWatcher()
    }

    /// Drop items older than the auto-clear window; 0 = never.
    func setAutoClear(_ minutes: Int) {
        autoClearMinutes = minutes
        defaults.set(minutes, forKey: Keys.Defaults.clipboardAutoClear)
        pruneExpired()
    }

    /// Remove expired items. Called lazily whenever the list is opened (no timer).
    func pruneExpired() {
        guard autoClearMinutes > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(autoClearMinutes) * 60)
        let before = items.count
        remove { !$0.isPinned && $0.copiedAt < cutoff }   // pins never expire
        if items.count != before { repository.save(items) }
    }

    /// Keep at most `maxItems` UNPINNED items (pins are exempt from the cap).
    private func trimUnpinned() {
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > maxItems else { return }
        let removeIDs = Set(unpinned.suffix(unpinned.count - maxItems).map(\.id))
        remove { removeIDs.contains($0.id) }
    }

    /// Remove matching items and delete any image blobs they own.
    private func remove(where predicate: (ClipboardItem) -> Bool) {
        for item in items where predicate(item) && item.content == .image {
            item.imageFiles?.forEach(ImageStore.delete)   // free every blob it owns
        }
        items.removeAll(where: predicate)
    }

    /// Master switch — turn the whole clipboard feature on/off.
    func setEnabled(_ on: Bool) {
        isEnabled = on
        defaults.set(on, forKey: Keys.Defaults.clipboardEnabled)
        updateMonitor()
    }

    /// Pause/resume recording copies. Existing history is kept either way.
    func setRecording(_ on: Bool) {
        isRecording = on
        defaults.set(on, forKey: Keys.Defaults.clipboardRecording)
        updateMonitor()
    }

    func toggleEnabled() { setEnabled(!isEnabled) }
    func toggleRecording() { setRecording(!isRecording) }

    /// History cap (unpinned). Trims immediately if lowered.
    func setMaxItems(_ n: Int) {
        maxItems = max(1, n)
        defaults.set(maxItems, forKey: Keys.Defaults.clipboardMaxItems)
        trimUnpinned()
        repository.save(items)
    }

    func setClearOnQuit(_ on: Bool) {
        clearOnQuit = on
        defaults.set(on, forKey: Keys.Defaults.clipboardClearOnQuit)
    }

    func setPinLimit(_ n: Int) {
        pinLimit = n
        defaults.set(n, forKey: Keys.Defaults.clipboardPinLimit)
    }

    func setRowDensity(_ d: RowDensity) {
        rowDensity = d
        defaults.set(d.rawValue, forKey: Keys.Defaults.clipboardRowDensity)
    }

    func setRestoreAfterPaste(_ on: Bool) {
        restoreAfterPaste = on
        defaults.set(on, forKey: Keys.Defaults.clipboardRestoreAfterPaste)
    }

    // MARK: - Excluded apps (two independent lists)

    func addExcludedRecordApp(_ id: String) {
        guard !excludedRecordApps.contains(id) else { return }
        excludedRecordApps.append(id)
        defaults.set(excludedRecordApps, forKey: Keys.Defaults.clipboardExcludeRecord)
    }
    func removeExcludedRecordApp(_ id: String) {
        excludedRecordApps.removeAll { $0 == id }
        defaults.set(excludedRecordApps, forKey: Keys.Defaults.clipboardExcludeRecord)
    }
    func addExcludedOpenApp(_ id: String) {
        guard !excludedOpenApps.contains(id) else { return }
        excludedOpenApps.append(id)
        defaults.set(excludedOpenApps, forKey: Keys.Defaults.clipboardExcludeOpen)
    }
    func removeExcludedOpenApp(_ id: String) {
        excludedOpenApps.removeAll { $0 == id }
        defaults.set(excludedOpenApps, forKey: Keys.Defaults.clipboardExcludeOpen)
    }

    /// Whether ⌘⇧V may open while `bundleID` is frontmost.
    func canOpenPopup(in bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return !excludedOpenApps.contains(bundleID)
    }

    /// Pin/unpin an item. Pinning is blocked once the pin limit is reached.
    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[idx].isPinned {
            items[idx].isPinned = false
        } else {
            guard pinnedCount < pinLimit else { return }
            items[idx].isPinned = true
        }
        repository.save(items)
    }

    /// Called from AppDelegate on quit.
    func handleTerminate() {
        if clearOnQuit { clear() }
    }

    /// Capture only when the feature is enabled AND recording.
    private func updateMonitor() {
        if isEnabled && isRecording { monitor.start() } else { monitor.stop() }
        updateScreenshotWatcher()   // master-off also stops the screenshot watcher
    }

    /// Put an item on the clipboard and promote it to the top (⌘C / menu "copy").
    func copyToPasteboard(_ item: ClipboardItem) {
        write(item, plain: false)
        promote(item)   // becomes the current/newest copy
    }

    /// Paste flow (restore-aware). When "restore after paste" is on: snapshot the current
    /// clipboard and DON'T promote the item; the caller restores after ⌘V.
    func pasteToPasteboard(_ item: ClipboardItem, plain: Bool = false) {
        if restoreAfterPaste { savedClipboard = snapshotClipboard() }
        write(item, plain: plain)
        if !restoreAfterPaste { promote(item) }   // promote only when not restoring
    }

    /// Put plain text on the clipboard for a paste (snippets) — restore-aware, not recorded.
    func pasteText(_ text: String) {
        if restoreAfterPaste { savedClipboard = snapshotClipboard() }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.syncChangeCount()
    }

    /// Put plain text on the clipboard (⌘C on a snippet) — not recorded.
    func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.syncChangeCount()
    }

    /// Restore the clipboard to what it held before the paste (if the toggle is on).
    func restoreClipboardIfNeeded() {
        guard restoreAfterPaste, let saved = savedClipboard else { return }
        pasteboard.clearContents()
        for entry in saved { pasteboard.setData(entry.data, forType: entry.type) }
        monitor.syncChangeCount()
        savedClipboard = nil
    }

    private func write(_ item: ClipboardItem, plain: Bool) {
        pasteboard.clearContents()
        switch item.content {
        case .image:
            if let names = item.imageFiles, !names.isEmpty {
                var objects: [NSPasteboardWriting] = []
                for name in names {
                    guard let data = ImageStore.data(name) else { continue }
                    let pbItem = NSPasteboardItem()
                    pbItem.setData(data, forType: .png)     // for editors / docs / browsers
                    objects.append(pbItem)
                    if let url = ImageStore.pasteURL(name) { objects.append(url as NSURL) }  // Finder
                }
                if !objects.isEmpty { pasteboard.writeObjects(objects) }
                monitor.syncChangeCount()
                return
            }
        case .files:
            if let paths = item.filePaths {
                pasteboard.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
            }
        case .text:
            if !plain, let data = item.richData, let type = item.richType {
                pasteboard.setData(data, forType: .init(type))   // formatted version
            }
            pasteboard.setString(item.text, forType: .string)    // plain (or only, when plain)
        }
        monitor.syncChangeCount()             // don't re-capture our own write
    }

    private func snapshotClipboard() -> [(data: Data, type: NSPasteboard.PasteboardType)] {
        (pasteboard.types ?? []).compactMap { type in
            pasteboard.data(forType: type).map { (data: $0, type: type) }
        }
    }

    func clear() {
        remove { _ in true }
        repository.save(items)
    }

    func deleteItem(_ item: ClipboardItem) {
        remove { $0.id == item.id }
        repository.save(items)
    }

    // MARK: - Item actions

    /// Open the first URL in a text item (link/email) in its default app.
    func openLink(_ item: ClipboardItem) {
        let raw = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let string = raw.contains("@") && !raw.contains("://") ? "mailto:\(raw)" : raw
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }

    /// Reveal a files item's paths in Finder.
    func revealInFinder(_ item: ClipboardItem) {
        let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Save an image item's blobs into ~/Downloads. Returns how many were written.
    @discardableResult
    /// Re-read the history list from storage (used after Import). Never touches the system clipboard.
    func reloadHistory() { items = repository.load() }

    /// Re-read every setting from storage (after an import or a reset-to-default) and re-apply.
    func reloadSettings() {
        isEnabled = defaults.object(forKey: Keys.Defaults.clipboardEnabled) as? Bool ?? true
        isRecording = defaults.object(forKey: Keys.Defaults.clipboardRecording) as? Bool ?? true
        autoClearMinutes = defaults.object(forKey: Keys.Defaults.clipboardAutoClear) as? Int ?? 0
        maxItems = defaults.object(forKey: Keys.Defaults.clipboardMaxItems) as? Int ?? AppConfig.clipboardHistoryLimit
        clearOnQuit = defaults.object(forKey: Keys.Defaults.clipboardClearOnQuit) as? Bool ?? false
        pinLimit = defaults.object(forKey: Keys.Defaults.clipboardPinLimit) as? Int ?? 5
        rowDensity = RowDensity(rawValue: defaults.string(forKey: Keys.Defaults.clipboardRowDensity) ?? "") ?? .regular
        excludedRecordApps = defaults.stringArray(forKey: Keys.Defaults.clipboardExcludeRecord) ?? []
        excludedOpenApps = defaults.stringArray(forKey: Keys.Defaults.clipboardExcludeOpen) ?? []
        restoreAfterPaste = defaults.bool(forKey: Keys.Defaults.clipboardRestoreAfterPaste)
        screenshotsToClipboard = defaults.bool(forKey: Keys.Defaults.clipboardScreenshots)
        screenshotFolderOverride = defaults.string(forKey: Keys.Defaults.clipboardScreenshotFolder)
        if isEnabled && isRecording { monitor.start() } else { monitor.stop() }
        updateScreenshotWatcher()
    }

    var historyCount: Int { items.count }   // for the import debug summary

    func saveImageToDownloads(_ item: ClipboardItem) -> Int {
        guard let names = item.imageFiles else { return 0 }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        var saved = 0
        for name in names {
            guard let data = ImageStore.data(name) else { continue }
            let dest = uniqueURL(in: downloads, base: "Perch Image", ext: "png")
            if (try? data.write(to: dest)) != nil { saved += 1 }
        }
        return saved
    }

    private func uniqueURL(in dir: URL, base: String, ext: String) -> URL {
        var url = dir.appendingPathComponent("\(base).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base) \(n).\(ext)")
            n += 1
        }
        return url
    }

    // MARK: - Private

    private func capture(_ copy: CapturedCopy) {
        if let source = copy.source, excludedRecordApps.contains(source) { return }  // excluded app
        guard let item = makeItem(from: copy) else { return }
        dedup(item)
        items.insert(item, at: 0)
        trimUnpinned()
        repository.save(items)
    }

    private func makeItem(from copy: CapturedCopy) -> ClipboardItem? {
        if let paths = copy.filePaths {
            return ClipboardItem(text: copy.text, sourceApp: copy.source, content: .files, filePaths: paths)
        }
        if let datas = copy.imageDatas {
            let blobs = datas.compactMap { ImageStore.save($0) }
            guard !blobs.isEmpty else { return nil }
            return ClipboardItem(text: copy.text, sourceApp: copy.source, content: .image, imageFiles: blobs)
        }
        return ClipboardItem(text: copy.text, sourceApp: copy.source,
                             richData: copy.richData, richType: copy.richType)
    }

    /// De-dup: text by text, files by paths. Images are always distinct.
    private func dedup(_ item: ClipboardItem) {
        switch item.content {
        case .text:  remove { $0.content == .text && $0.text == item.text }
        case .files: remove { $0.content == .files && $0.filePaths == item.filePaths }
        case .image: break
        }
    }

    /// Move an existing item to the top without recapturing (used after paste).
    private func promote(_ item: ClipboardItem) {
        guard let existing = items.first(where: { $0.id == item.id }) else { return }
        items.removeAll { $0.id == item.id }
        items.insert(existing, at: 0)
        repository.save(items)
    }
}
