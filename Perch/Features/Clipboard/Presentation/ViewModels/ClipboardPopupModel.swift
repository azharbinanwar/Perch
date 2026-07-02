//
//  ClipboardPopupModel.swift
//  Perch
//
//  Drives the ⌘⇧V popup. One selectable list = snippets (top) + clipboard items.
//  Selection is by id; the clipboard list is frozen while open so background copies
//  don't reshuffle it; one highlight, last-input-wins between keyboard and mouse.
//

import Foundation
import Observation

enum PopupMode { case clipboard, snippets }

@Observable
final class ClipboardPopupModel {
    var search = ""
    var mode: PopupMode = .clipboard
    var selectedID: UUID?
    var needsPermission = false
    var showHelp = false
    var previewing = false
    var notice: String?

    var onPaste: () -> Void = {}
    var onPasteKeepOpen: () -> Void = {}
    var onClose: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    private let clipboard: ClipboardViewModel
    private let snippets: SnippetViewModel
    private var frozenItems: [ClipboardItem] = []
    private var acceptHover = false
    private var suppressHover = false

    init(clipboard: ClipboardViewModel, snippets: SnippetViewModel) {
        self.clipboard = clipboard
        self.snippets = snippets
    }

    // MARK: - Visible content

    /// Clipboard items, matched on text OR source-app name.
    var visibleItems: [ClipboardItem] {
        guard !search.isEmpty else { return frozenItems }
        return frozenItems.filter { item in
            if item.text.localizedCaseInsensitiveContains(search) { return true }
            if let name = AppIcon.name(forBundleID: item.sourceApp),
               name.localizedCaseInsensitiveContains(search) { return true }
            return false
        }
    }

    /// Snippets, matched on name OR text.
    var visibleSnippets: [Snippet] {
        guard !search.isEmpty else { return snippets.snippets }
        return snippets.snippets.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search)
        }
    }

    /// Keyboard-selectable ids for the current mode only.
    private var selectableIDs: [UUID] {
        switch mode {
        case .clipboard: return visibleItems.map(\.id)
        case .snippets:  return visibleSnippets.map(\.id)
        }
    }

    func toggleMode() { setMode(mode == .clipboard ? .snippets : .clipboard) }

    func setMode(_ newMode: PopupMode) {
        guard newMode != mode else { return }
        mode = newMode
        search = ""
        selectedID = selectableIDs.first
        suppressHoverBriefly()
    }

    private var selectedSnippet: Snippet? { visibleSnippets.first { $0.id == selectedID } }
    private var selectedItem: ClipboardItem? { visibleItems.first { $0.id == selectedID } }
    private var selectedIndex: Int? { selectedID.flatMap { id in selectableIDs.firstIndex(of: id) } }

    var isRecording: Bool { clipboard.isRecording }
    func resumeRecording() { clipboard.setRecording(true) }
    var rowDensity: RowDensity { clipboard.rowDensity }

    // MARK: - Open

    func open() {
        clipboard.pruneExpired()
        search = ""
        mode = .clipboard
        showHelp = false
        previewing = false
        notice = nil
        if case .loaded(let items) = clipboard.state { frozenItems = items } else { frozenItems = [] }
        selectedID = selectableIDs.first
        acceptHover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.acceptHover = true }
    }

    // MARK: - Navigation

    func moveDown() {
        let ids = selectableIDs
        guard !ids.isEmpty else { return }
        let i = selectedIndex ?? -1
        selectedID = ids[(i + 1) >= ids.count ? 0 : i + 1]
        suppressHoverBriefly()
    }

    func moveUp() {
        let ids = selectableIDs
        guard !ids.isEmpty else { return }
        let i = selectedIndex ?? 0
        selectedID = ids[(i - 1) < 0 ? ids.count - 1 : i - 1]
        suppressHoverBriefly()
    }

    func selectFirst() { selectedID = selectableIDs.first; suppressHoverBriefly() }
    func selectLast() { selectedID = selectableIDs.last; suppressHoverBriefly() }

    private func suppressHoverBriefly() {
        suppressHover = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.suppressHover = false }
    }

    // MARK: - Search

    func appendToSearch(_ text: String) { search += text; selectedID = selectableIDs.first }
    func deleteSearchChar() { if !search.isEmpty { search.removeLast(); selectedID = selectableIDs.first } }

    func escape() {
        if previewing { previewing = false }
        else if showHelp { showHelp = false }
        else { onClose() }
    }

    func toggleHelp() { showHelp.toggle() }

    // MARK: - Preview

    var previewItem: ClipboardItem? {
        if let snippet = selectedSnippet { return ClipboardItem(text: snippet.text) }
        return selectedItem
    }

    func togglePreview() {
        guard selectedSnippet != nil || selectedItem != nil else { return }
        previewing.toggle()
    }

    // MARK: - Paste actions

    func pasteSelected() {
        if let snippet = selectedSnippet { clipboard.pasteText(snippet.text); onPaste() }
        else if let item = selectedItem { clipboard.pasteToPasteboard(item); onPaste() }
    }

    func pastePlainSelected() {
        if let snippet = selectedSnippet { clipboard.pasteText(snippet.text); onPaste() }
        else if let item = selectedItem { clipboard.pasteToPasteboard(item, plain: true); onPaste() }
    }

    func pasteSelectedKeepingOpen() {
        if let snippet = selectedSnippet { clipboard.pasteText(snippet.text); onPasteKeepOpen() }
        else if let item = selectedItem { clipboard.copyToPasteboard(item); onPasteKeepOpen() }
    }

    func copySelectedWithoutPaste() {
        if let snippet = selectedSnippet { clipboard.copyText(snippet.text); onClose() }
        else if let item = selectedItem { clipboard.copyToPasteboard(item); onClose() }
    }

    func restoreClipboardIfNeeded() { clipboard.restoreClipboardIfNeeded() }

    /// ⌘1–9 quick pick across the whole selectable order.
    func quickPick(_ number: Int) {
        let ids = selectableIDs
        guard ids.indices.contains(number - 1) else { return }
        selectedID = ids[number - 1]
        pasteSelected()
    }

    // MARK: - Pin / delete (clipboard items only)

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
        let pinnedSorted = frozenItems.filter(\.isPinned).sorted { $0.copiedAt > $1.copiedAt }
        let recentSorted = frozenItems.filter { !$0.isPinned }.sorted { $0.copiedAt > $1.copiedAt }
        frozenItems = pinnedSorted + recentSorted
        selectedID = item.id
    }

    func togglePinSelected() {
        if let item = selectedItem { togglePin(item) }
    }

    func deleteSelected() {
        if let item = selectedItem { delete(item) }
    }

    func delete(_ item: ClipboardItem) {
        clipboard.deleteItem(item)
        frozenItems.removeAll { $0.id == item.id }
        if selectedID == item.id { selectedID = selectableIDs.first }
    }

    func clearAll() {
        clipboard.clear()
        frozenItems = []
        selectedID = selectableIDs.first
        search = ""
    }

    // MARK: - Mouse

    func hover(id: UUID) {
        guard acceptHover, !suppressHover else { return }
        selectedID = id
    }

    func paste(_ item: ClipboardItem) { selectedID = item.id; pasteSelected() }
    func pasteSnippet(_ snippet: Snippet) { selectedID = snippet.id; pasteSelected() }

    // MARK: - Notice

    private func showNotice(_ text: String) {
        notice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.notice == text { self?.notice = nil }
        }
    }
}
