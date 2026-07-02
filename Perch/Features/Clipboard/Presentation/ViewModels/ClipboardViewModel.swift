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

    private let repository: ClipboardRepository
    private let monitor: ClipboardMonitor
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
         monitor: ClipboardMonitor = ServiceLocator.shared.resolve(ClipboardMonitor.self)) {
        self.repository = repository
        self.monitor = monitor
        self.isEnabled = defaults.object(forKey: Keys.Defaults.clipboardEnabled) as? Bool ?? true
        self.isRecording = defaults.object(forKey: Keys.Defaults.clipboardRecording) as? Bool ?? true
        self.autoClearMinutes = defaults.object(forKey: Keys.Defaults.clipboardAutoClear) as? Int ?? 0
        self.maxItems = defaults.object(forKey: Keys.Defaults.clipboardMaxItems) as? Int ?? AppConfig.clipboardHistoryLimit
        self.clearOnQuit = defaults.object(forKey: Keys.Defaults.clipboardClearOnQuit) as? Bool ?? false
        self.pinLimit = defaults.object(forKey: Keys.Defaults.clipboardPinLimit) as? Int ?? 5
        self.rowDensity = RowDensity(rawValue: defaults.string(forKey: Keys.Defaults.clipboardRowDensity) ?? "") ?? .regular
        self.excludedRecordApps = defaults.stringArray(forKey: Keys.Defaults.clipboardExcludeRecord) ?? []
        self.excludedOpenApps = defaults.stringArray(forKey: Keys.Defaults.clipboardExcludeOpen) ?? []
        self.items = repository.load()
        state = items.isEmpty ? .empty : .loaded(items)
    }

    /// Begin watching the pasteboard. Called once from AppDelegate.
    func start() {
        monitor.onCopy = { [weak self] copy in
            self?.capture(copy)
        }
        updateMonitor()
        pruneExpired()
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
        let kept = items.filter { $0.isPinned || $0.copiedAt >= cutoff }   // pins never expire
        if kept.count != items.count {
            items = kept
            repository.save(items)
        }
    }

    /// Keep at most `maxItems` UNPINNED items (pins are exempt from the cap).
    private func trimUnpinned() {
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > maxItems else { return }
        let removeIDs = Set(unpinned.suffix(unpinned.count - maxItems).map(\.id))
        items.removeAll { removeIDs.contains($0.id) }
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
    }

    /// Copy an item back to the pasteboard and move it to the top of history.
    /// (Paste-on-Enter arrives with the Shift+Cmd+V panel milestone.)
    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        if let data = item.richData, let type = item.richType {
            pasteboard.setData(data, forType: .init(type))   // formatted version
        }
        pasteboard.setString(item.text, forType: .string)    // + plain fallback
        monitor.syncChangeCount()             // don't re-capture our own write
        capture(item)                          // move to top, keep origin + rich
    }

    /// Paste stripped of formatting — plain text only.
    func copyPlainToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        monitor.syncChangeCount()
        capture(item)   // keep the item (with its rich data) at the top
    }

    func clear() {
        items.removeAll()
        repository.save(items)
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        repository.save(items)
    }

    // MARK: - Private

    private func capture(_ copy: CapturedCopy) {
        if let source = copy.source, excludedRecordApps.contains(source) { return }  // excluded app
        items.removeAll { $0.text == copy.text }        // de-dup
        items.insert(ClipboardItem(text: copy.text, sourceApp: copy.source,
                                   richData: copy.richData, richType: copy.richType), at: 0)
        trimUnpinned()
        repository.save(items)
    }

    /// Re-capture an existing item (e.g. after pasting) — moves it to the top, keeps everything.
    private func capture(_ item: ClipboardItem) {
        capture(CapturedCopy(text: item.text, source: item.sourceApp,
                             richData: item.richData, richType: item.richType))
    }
}
