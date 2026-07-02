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
            if model.needsPermission { permissionBanner }
            if !model.isRecording { pausedBanner }
            if let notice = model.notice { noticeBanner(notice) }
            searchBar
            modeToggle
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 560, height: 480)
        .background(.regularMaterial)
        .overlay { if model.showHelp { helpOverlay } }
        .overlay {
            if model.previewing, let item = model.previewItem {
                ClipboardPreviewCard(item: item) { model.previewing = false }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
    }

    // MARK: - Shortcuts cheat-sheet

    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture { model.showHelp = false }
            shortcutsGrid
                .padding(20)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
        }
    }

    private var shortcutsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard Shortcuts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ShortcutColumns()
        }
    }

    // MARK: - Permission banner

    private var permissionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Grant Accessibility for keyboard control & paste")
                .font(.system(size: 12))
            Spacer()
            Button("Open Settings") { openAccessibilitySettings() }
                .font(.system(size: 11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
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

    private var modeToggle: some View {
        Picker("", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
            Text("Clipboard").tag(PopupMode.clipboard)
            Text("Snippets").tag(PopupMode.snippets)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var list: some View {
        switch model.mode {
        case .clipboard: clipboardList
        case .snippets:  snippetsList
        }
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
                }
                .onChange(of: model.selectedID) { _, id in
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
                .onChange(of: model.selectedID) { _, id in
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
            onPin: { withAnimation(.easeInOut(duration: 0.15)) { model.togglePin(item) } },
            onHover: { model.hover(id: item.id) }
        )
        .id(item.id)
    }

    private func snippetRow(_ snippet: Snippet, number: Int?) -> some View {
        SnippetPopupRow(
            snippet: snippet,
            number: number,
            isSelected: snippet.id == model.selectedID,
            onPaste: { model.pasteSnippet(snippet) },
            onHover: { model.hover(id: snippet.id) }
        )
        .id(snippet.id)
    }

    // MARK: - Empty state (first launch / cleared)

    private var emptyStart: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Nothing copied yet").font(.headline)
                Text("Copy anything and it'll show up here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .center, spacing: 10) {
                Text("Keyboard Shortcuts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ShortcutColumns()
            }
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
