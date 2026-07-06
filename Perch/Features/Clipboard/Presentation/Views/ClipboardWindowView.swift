//
//  ClipboardWindowView.swift
//  Perch
//
//  The ⌘⇧V popup. State lives in ClipboardPopupModel, driven by the panel's key tap —
//  this view just renders. No focused text field, so the target app keeps keyboard focus.
//

import SwiftUI

struct ClipboardWindowView: View {
    let model: ClipboardPopupModel

    var body: some View {
        VStack(spacing: 0) {
            if model.needsPermission {
                AccessibilityBanner(message: "Grant Accessibility for keyboard control & paste")
            }
            if !model.isRecording { pausedBanner }
            if let notice = model.notice { noticeBanner(notice) }
            searchBar
            categoryBar
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 640, height: 500)
        .background(.regularMaterial)
        .overlay { if model.showHelp { ClipboardShortcutsOverlay { model.showHelp = false } } }
        .overlay {
            if model.previewing, let item = model.previewItem {
                ClipboardPreviewCard(
                    item: item,
                    index: Binding(get: { model.previewIndex }, set: { model.previewIndex = $0 })
                ) { model.previewing = false }
            }
        }
        .overlay {
            if model.editing {
                ClipboardEditOverlay(
                    text: Binding(get: { model.editText }, set: { model.editText = $0 }),
                    onPaste: model.commitEdit,
                    onCancel: model.cancelEdit
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
    }

    // MARK: - Paused banner

    private var pausedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
            Text("Recording paused — new copies aren't saved")
                .font(.system(size: 12))
            Spacer()
            Button("Resume") { model.resumeRecording() }
                .font(.system(size: 11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "pin.slash.fill").foregroundStyle(.orange)
            Text(text).font(.system(size: 12))
            Spacer()
            Button("Open Settings") { model.onOpenSettings() }
                .font(.system(size: 11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
    }

    // MARK: - Search (display only; typing is captured by the key tap)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            if model.search.isEmpty {
                Text("Type to search").foregroundStyle(.tertiary)
            } else {
                Text(model.search)
            }
            Spacer()
        }
        .font(.system(size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var categoryBar: some View {
        Picker("", selection: Binding(get: { model.category }, set: { model.setCategory($0) })) {
            ForEach(model.availableCategories) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var list: some View {
        if model.category.isSnippets { snippetsList } else { clipboardList }
    }

    @ViewBuilder
    private var clipboardList: some View {
        let items = model.visibleItems
        if items.isEmpty {
            if model.search.isEmpty {
                emptyStart
            } else {
                noMatches
            }
        } else {
            let pinned = items.filter(\.isPinned)
            let recent = items.filter { !$0.isPinned }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if !pinned.isEmpty {
                            SectionLabel(title: "Pinned")
                            ForEach(Array(pinned.enumerated()), id: \.element.id) { i, item in
                                itemRow(item, number: numberFor(i))
                            }
                        }
                        if !recent.isEmpty {
                            if !pinned.isEmpty { SectionLabel(title: "Recent") }
                            ForEach(Array(recent.enumerated()), id: \.element.id) { i, item in
                                itemRow(item, number: numberFor(pinned.count + i))
                            }
                        }
                    }
                    .padding(8)
                    .id(model.listGen)   // pin/unpin → whole list rebuilt fresh, no stale row state
                }
                .onContinuousHover { phase in
                    if case .active = phase { model.pointerMoved() }   // real movement only
                }
                .onChange(of: model.scrollTarget) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    @ViewBuilder
    private var snippetsList: some View {
        let snippets = model.visibleSnippets
        if snippets.isEmpty {
            if model.search.isEmpty {
                ContentUnavailableView("No Snippets", systemImage: "note.text",
                    description: Text("Create snippets in Perch → Snippets."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noMatches
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(snippets.enumerated()), id: \.element.id) { i, snippet in
                            snippetRow(snippet, number: numberFor(i))
                        }
                    }
                    .padding(8)
                }
                .onContinuousHover { phase in
                    if case .active = phase { model.pointerMoved() }   // real movement only
                }
                .onChange(of: model.scrollTarget) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    private var noMatches: some View {
        ContentUnavailableView("No Matches", systemImage: "magnifyingglass",
            description: Text("Nothing matches “\(model.search)”."))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func numberFor(_ index: Int) -> Int? { index < 9 ? index + 1 : nil }

    private func itemRow(_ item: ClipboardItem, number: Int?) -> some View {
        ClipboardItemRow(
            item: item,
            density: model.rowDensity,
            number: number,
            isSelected: item.id == model.selectedID,
            highlightsOnHover: false,
            onCopy: { model.paste(item) },
            onDelete: { model.delete(item) },
            onPin: { model.togglePin(item) },
            onHover: { model.hover(id: item.id) }
        )
        .id(item.id)
        .onDrag { dragProvider(for: item) }
        .contextMenu { itemMenu(item) }
    }

    /// Drag a row out to Finder / another app: text → string, file/image → file URL.
    private func dragProvider(for item: ClipboardItem) -> NSItemProvider {
        switch item.content {
        case .text:
            return NSItemProvider(object: item.text as NSString)
        case .files:
            if let path = item.filePaths?.first {
                return NSItemProvider(contentsOf: URL(fileURLWithPath: path)) ?? NSItemProvider()
            }
        case .image:
            if let name = item.imageFile, let url = ImageStore.pasteURL(name) {
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
        }
        return NSItemProvider()
    }

    @ViewBuilder
    private func itemMenu(_ item: ClipboardItem) -> some View {
        ForEach(ClipboardAction.available(for: item)) { action in
            Button {
                model.perform(action, on: item)
            } label: {
                Label(action.title, systemImage: action.icon)
            }
        }
        Divider()
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { model.togglePin(item) }
        } label: {
            Label(clipboardIsPinned(item) ? "Unpin" : "Pin", systemImage: "pin")
        }
        Button(role: .destructive) { model.delete(item) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func clipboardIsPinned(_ item: ClipboardItem) -> Bool { item.isPinned }

    private func snippetRow(_ snippet: Snippet, number: Int?) -> some View {
        SnippetPopupRow(
            snippet: snippet,
            number: number,
            isSelected: snippet.id == model.selectedID,
            abbreviationBadge: model.abbreviationBadge(for: snippet),
            onPaste: { model.pasteSnippet(snippet) },
            onHover: { model.hover(id: snippet.id) }
        )
        .id(snippet.id)
    }

    // MARK: - Empty state (first launch / cleared)

    private var emptyStart: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Nothing copied yet").font(.headline)
            Text("Copy anything and it'll show up here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            ForEach(PopupShortcuts.footer) { shortcut in
                if shortcut.keys == "⌘/" {
                    Button { model.toggleHelp() } label: {
                        legend(shortcut.keys, shortcut.footerLabel ?? "")
                    }
                    .buttonStyle(.plain)
                } else {
                    legend(shortcut.keys, shortcut.footerLabel ?? "")
                }
            }
            Spacer()
            Button("Clear All") { model.clearAll() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func legend(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
        }
    }
}
