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

@Observable
final class ClipboardPopupModel {
    var search = ""
    var category: ClipboardCategory = .all
    var selectedID: UUID?
    var scrollTarget: UUID?   // keyboard-driven only; the list scrolls to this, not to hover
    var needsPermission = false
    var showHelp = false
    var previewing = false
    var notice: String?
    var editing = false
    var editText = ""
    var confirmingClear = false   // in-panel "clear all?" confirm (native alert squares the corners)

    var onPaste: () -> Void = {}
    var onPasteKeepOpen: () -> Void = {}
    var onClose: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onBeginEdit: () -> Void = {}    // controller: pause key-tap, make panel key
    var onEndEdit: () -> Void = {}      // controller: restart key-tap

    private let clipboard: ClipboardViewModel
    private let snippets: SnippetViewModel
    private var frozenItems: [ClipboardItem] = []
    private var acceptHover = false
    private var suppressHover = false

    /// Bumped whenever the list is rebuilt (pin/unpin). The view uses it as the list's identity,
    /// so every row view is recreated fresh — no reused row can keep a stale highlight.
    var listGen = 0

    init(clipboard: ClipboardViewModel, snippets: SnippetViewModel) {
        self.clipboard = clipboard
        self.snippets = snippets
    }

    // MARK: - Visible content

    /// Clipboard items in the current category, matched on text OR source-app name.
    var visibleItems: [ClipboardItem] {
        guard !category.isSnippets else { return [] }
        return frozenItems.filter { category.matches($0) && matchesSearch($0) }
    }

    private func matchesSearch(_ item: ClipboardItem) -> Bool {
        guard !search.isEmpty else { return true }
        if item.text.localizedCaseInsensitiveContains(search) { return true }
        if let name = AppIcon.name(forBundleID: item.sourceApp),
           name.localizedCaseInsensitiveContains(search) { return true }
        return false
    }

    /// The switcher's segments: All + content types that have items + Snippets.
    var availableCategories: [ClipboardCategory] {
        var cats: [ClipboardCategory] = [.all]
        cats += ClipboardCategory.contentTypes.filter { type in frozenItems.contains { type.matches($0) } }
        cats.append(.snippets)
        return cats
    }

    func setCategory(_ newCategory: ClipboardCategory) {
        guard newCategory != category else { return }
        category = newCategory
        search = ""
        keyboardSelect(selectableIDs.first)
    }

    /// Tab → next, ⇧Tab → previous available category (both wrap).
    func cycleCategory(_ delta: Int = 1) {
        let cats = availableCategories
        guard let i = cats.firstIndex(of: category) else { return }
        let n = cats.count
        setCategory(cats[((i + delta) % n + n) % n])
    }

    /// ⌥1–9 → jump to the Nth available category.
    func selectCategory(_ number: Int) {
        let cats = availableCategories
        guard cats.indices.contains(number - 1) else { return }
        setCategory(cats[number - 1])
    }

    /// Snippets, matched on name OR text.
    var visibleSnippets: [Snippet] {
        guard !search.isEmpty else { return snippets.snippets }
        return snippets.snippets.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search)
        }
    }

    /// Keyboard-selectable ids for the current category only.
    private var selectableIDs: [UUID] {
        category.isSnippets ? visibleSnippets.map(\.id) : visibleItems.map(\.id)
    }

    private var selectedSnippet: Snippet? {
        category.isSnippets ? visibleSnippets.first { $0.id == selectedID } : nil
    }
    private var selectedItem: ClipboardItem? {
        category.isSnippets ? nil : visibleItems.first { $0.id == selectedID }
    }
    private var selectedIndex: Int? { selectedID.flatMap { id in selectableIDs.firstIndex(of: id) } }

    var isRecording: Bool { clipboard.isRecording }
    func resumeRecording() { clipboard.setRecording(true) }
    var rowDensity: RowDensity { clipboard.rowDensity }

    // MARK: - Open

    func open() {
        clipboard.pruneExpired()
        search = ""
        category = .all
        showHelp = false
        previewing = false
        editing = false
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
        keyboardSelect(ids[(i + 1) >= ids.count ? 0 : i + 1])
    }

    func moveUp() {
        let ids = selectableIDs
        guard !ids.isEmpty else { return }
        let i = selectedIndex ?? 0
        keyboardSelect(ids[(i - 1) < 0 ? ids.count - 1 : i - 1])
    }

    func selectFirst() { keyboardSelect(selectableIDs.first) }
    func selectLast() { keyboardSelect(selectableIDs.last) }

    /// Keyboard-driven selection: also sets the scroll target so the row is kept in view.
    /// (Hover only sets `selectedID`, so the list never auto-scrolls under the mouse.)
    private func keyboardSelect(_ id: UUID?) {
        selectedID = id
        scrollTarget = id
        suppressHoverBriefly()
    }

    private func suppressHoverBriefly() {
        suppressHover = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.suppressHover = false }
    }

    // MARK: - Search

    func appendToSearch(_ text: String) { search += text; keyboardSelect(selectableIDs.first) }
    func deleteSearchChar() { if !search.isEmpty { search.removeLast(); keyboardSelect(selectableIDs.first) } }

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

    /// Carousel position within the previewed item (driven by ← →).
    var previewIndex = 0

    private var previewImageCount: Int {
        switch previewItem?.content {
        case .image: return previewItem?.imageFiles?.count ?? 0
        case .files: return previewItem?.filePaths?.count ?? 0
        default:     return 0
        }
    }

    /// Move the carousel; wraps. No-op when there's nothing to page through.
    func previewStep(_ delta: Int) {
        let count = previewImageCount
        guard count > 1 else { return }
        previewIndex = (previewIndex + delta + count) % count
    }

    func togglePreview() {
        guard selectedSnippet != nil || selectedItem != nil else { return }
        previewIndex = 0
        previewing.toggle()
    }

    // MARK: - Paste actions

    func pasteSelected() {
        if let snippet = selectedSnippet { clipboard.pasteText(snippets.resolvedText(snippet.text)); onPaste() }
        else if let item = selectedItem { clipboard.pasteToPasteboard(item); onPaste() }
    }

    func pastePlainSelected() {
        if let snippet = selectedSnippet { clipboard.pasteText(snippets.resolvedText(snippet.text)); onPaste() }
        else if let item = selectedItem { clipboard.pasteToPasteboard(item, plain: true); onPaste() }
    }

    func pasteSelectedKeepingOpen() {
        if let snippet = selectedSnippet { clipboard.pasteText(snippets.resolvedText(snippet.text)); onPasteKeepOpen() }
        else if let item = selectedItem { clipboard.copyToPasteboard(item); onPasteKeepOpen() }
    }

    func copySelectedWithoutPaste() {
        if let snippet = selectedSnippet { clipboard.copyText(snippet.text); onClose() }
        else if let item = selectedItem { clipboard.copyToPasteboard(item); onClose() }
    }

    // MARK: - Item actions

    func perform(_ action: ClipboardAction, on item: ClipboardItem) {
        switch action {
        case .openLink:       clipboard.openLink(item); onClose()
        case .revealInFinder: clipboard.revealInFinder(item); onClose()
        case .saveImage:
            let n = clipboard.saveImageToDownloads(item)
            showNotice(n > 0 ? "Saved \(n) image\(n == 1 ? "" : "s") to Downloads" : "Couldn't save image")
        case .copyPlain:      clipboard.copyText(item.text); onClose()
        }
    }

    /// Run an action from the keyboard against the selected item, if it applies.
    func performOnSelected(_ action: ClipboardAction) {
        guard let item = selectedItem, action.applies(to: item) else { return }
        perform(action, on: item)
    }

    // MARK: - Edit before paste (text items only)

    func startEditingSelected() {
        guard let item = selectedItem, item.content == .text else { return }
        editText = item.text
        editing = true
        onBeginEdit()   // controller pauses the key-tap and makes the panel key
    }

    /// Paste the edited text into the target app; the stored clip is untouched.
    func commitEdit() {
        guard editing else { return }
        let text = editText
        editing = false
        onEndEdit()
        clipboard.pasteText(text)
        onPaste()
    }

    func cancelEdit() {
        guard editing else { return }
        editing = false
        onEndEdit()   // controller restarts the key-tap; back to the list
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
        listGen += 1                        // new list identity → every row view is rebuilt fresh (no stale highlight)
        selectedID = selectableIDs.first    // fresh list starts with exactly one focused item
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

    private var pointerActive = false   // true only while the pointer is actually moving
    private var pointerGen = 0

    /// Called on real pointer movement (not when content scrolls under a still cursor).
    func pointerMoved() {
        pointerActive = true
        pointerGen += 1
        let gen = pointerGen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.pointerGen == gen else { return }
            self.pointerActive = false
        }
    }

    func hover(id: UUID) {
        guard acceptHover, !suppressHover, pointerActive else { return }   // moving mouse only
        selectedID = id
    }

    func paste(_ item: ClipboardItem) { selectedID = item.id; pasteSelected() }
    func pasteSnippet(_ snippet: Snippet) { selectedID = snippet.id; pasteSelected() }

    /// ";addr" for the row badge — only while text expansion is on (else nil, badge hidden).
    func abbreviationBadge(for snippet: Snippet) -> String? {
        guard snippets.expansionEnabled, let abbreviation = snippet.abbreviation else { return nil }
        return snippets.expansionPrefix.rawValue + abbreviation + snippets.expansionPrefix.rawValue
    }

    // MARK: - Notice

    private func showNotice(_ text: String) {
        notice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.notice == text { self?.notice = nil }
        }
    }
}
