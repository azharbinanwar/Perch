//
//  ClipboardPopupModel.swift
//  Perch
//
//  Drives the ⌘⇧V popup. Selection is by item id (survives reordering), the list is
//  frozen while open (background copies don't reshuffle it), and there's one highlight
//  with last-input-wins between keyboard and mouse.
//

import Foundation
import Observation

@Observable
final class ClipboardPopupModel {
    var search = ""
    var selectedID: UUID?
    var needsPermission = false
    var showHelp = false
    var previewing = false   // full-content preview (Space)
    var notice: String?   // transient message (e.g. pin limit reached)

    func toggleHelp() { showHelp.toggle() }

    var isRecording: Bool { clipboard.isRecording }
    func resumeRecording() { clipboard.setRecording(true) }

    var rowDensity: RowDensity { clipboard.rowDensity }

    /// Pin/unpin without reshuffling the open list — just reflect the new state in place.
    func togglePin(_ item: ClipboardItem) {
        let alreadyPinned = clipboard.isPinned(item.id)
        if !alreadyPinned && clipboard.pinnedCount >= clipboard.pinLimit {
            showNotice("Pin limit reached (\(clipboard.pinLimit)). Unpin one, or raise it in Settings.")
            return
        }
        clipboard.togglePin(item)
        if let idx = frozenItems.firstIndex(where: { $0.id == item.id }) {
            frozenItems[idx].isPinned = clipboard.isPinned(item.id)
        }
        // Reorder now: pinned first, each group newest-first — so an unpinned item
        // drops back to its time-sorted spot, and a freshly-pinned one jumps to the top.
        let pinnedSorted = frozenItems.filter(\.isPinned).sorted { $0.copiedAt > $1.copiedAt }
        let recentSorted = frozenItems.filter { !$0.isPinned }.sorted { $0.copiedAt > $1.copiedAt }
        frozenItems = pinnedSorted + recentSorted
        selectedID = item.id
    }

    private func showNotice(_ text: String) {
        notice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.notice == text { self?.notice = nil }
        }
    }

    func togglePinSelected() {
        if let item = visibleItems.first(where: { $0.id == selectedID }) { togglePin(item) }
    }

    var onPaste: () -> Void = {}          // paste + close
    var onPasteKeepOpen: () -> Void = {}  // paste, leave popup up
    var onClose: () -> Void = {}
    var onOpenSettings: () -> Void = {}   // open the main window (Clipboard tab)

    private let clipboard: ClipboardViewModel
    private var frozenItems: [ClipboardItem] = []   // snapshot taken when the popup opens
    private var acceptHover = false                 // ignore the cursor merely resting on open
    private var suppressHover = false               // ignore hover right after arrow keys

    init(clipboard: ClipboardViewModel) {
        self.clipboard = clipboard
    }

    /// The clipboard shows everything it keeps (capped by ClipboardViewModel.maxItems).
    /// A row matches on its text OR its source-app name (so "whatsapp" finds every
    /// WhatsApp copy plus any text that mentions it).
    var visibleItems: [ClipboardItem] {
        guard !search.isEmpty else { return frozenItems }
        return frozenItems.filter { item in
            if item.text.localizedCaseInsensitiveContains(search) { return true }
            if let name = AppIcon.name(forBundleID: item.sourceApp),
               name.localizedCaseInsensitiveContains(search) { return true }
            return false
        }
    }

    /// Called each time the popup opens: freeze the list, select the top item.
    func open() {
        clipboard.pruneExpired()   // lazy auto-clear on access (no timer)
        search = ""
        showHelp = false
        previewing = false
        notice = nil
        if case .loaded(let items) = clipboard.state { frozenItems = items } else { frozenItems = [] }
        selectedID = visibleItems.first?.id
        acceptHover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.acceptHover = true }
    }

    private var selectedIndex: Int? { visibleItems.firstIndex { $0.id == selectedID } }
    private var selectedItem: ClipboardItem? { visibleItems.first { $0.id == selectedID } }

    /// The item shown in the full-content preview (follows the selection).
    var previewItem: ClipboardItem? { selectedItem }

    func togglePreview() {
        guard selectedItem != nil else { return }
        previewing.toggle()
    }

    // MARK: - Keyboard: navigation

    func moveDown() {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let i = selectedIndex ?? -1
        selectedID = items[(i + 1) >= items.count ? 0 : i + 1].id   // wrap
        suppressHoverBriefly()
    }

    func moveUp() {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let i = selectedIndex ?? 0
        selectedID = items[(i - 1) < 0 ? items.count - 1 : i - 1].id  // wrap
        suppressHoverBriefly()
    }

    func selectFirst() { selectedID = visibleItems.first?.id; suppressHoverBriefly() }
    func selectLast() { selectedID = visibleItems.last?.id; suppressHoverBriefly() }

    /// After an arrow key, ignore hover for a moment — otherwise a row scrolling under a
    /// still cursor fires onHover and hijacks the selection.
    private func suppressHoverBriefly() {
        suppressHover = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.suppressHover = false
        }
    }

    // MARK: - Keyboard: search

    func appendToSearch(_ text: String) { search += text; selectedID = visibleItems.first?.id }
    func deleteSearchChar() { if !search.isEmpty { search.removeLast(); selectedID = visibleItems.first?.id } }

    /// Esc: dismiss preview/help first, otherwise close the popup.
    func escape() {
        if previewing { previewing = false }
        else if showHelp { showHelp = false }
        else { onClose() }
    }

    // MARK: - Keyboard: actions

    func pasteSelected() {
        guard let item = selectedItem else { return }
        clipboard.pasteToPasteboard(item)
        onPaste()
    }

    /// Paste without formatting.
    func pastePlainSelected() {
        guard let item = selectedItem else { return }
        clipboard.pasteToPasteboard(item, plain: true)
        onPaste()
    }

    func restoreClipboardIfNeeded() { clipboard.restoreClipboardIfNeeded() }

    func pasteSelectedKeepingOpen() {
        guard let item = selectedItem else { return }
        clipboard.copyToPasteboard(item)
        onPasteKeepOpen()
    }

    func copySelectedWithoutPaste() {
        guard let item = selectedItem else { return }
        clipboard.copyToPasteboard(item)
        onClose()
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item)
    }

    /// ⌘1–9 quick pick (1-based).
    func quickPick(_ number: Int) {
        let items = visibleItems
        guard items.indices.contains(number - 1) else { return }
        selectedID = items[number - 1].id
        pasteSelected()
    }

    // MARK: - Mouse

    /// Hover moves the selection only after the popup has settled (so resting on open is ignored).
    func hover(_ item: ClipboardItem) {
        guard acceptHover, !suppressHover else { return }
        selectedID = item.id
    }

    func paste(_ item: ClipboardItem) { selectedID = item.id; pasteSelected() }

    func delete(_ item: ClipboardItem) {
        clipboard.deleteItem(item)
        frozenItems.removeAll { $0.id == item.id }
        if selectedID == item.id { selectedID = visibleItems.first?.id }
    }

    func clearAll() {
        clipboard.clear()
        frozenItems = []
        selectedID = nil
        search = ""
    }
}
