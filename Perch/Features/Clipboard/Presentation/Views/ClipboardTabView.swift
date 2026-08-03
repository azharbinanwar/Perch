//
//  ClipboardTabView.swift
//  Perch
//
//  Main-window Clipboard page — a control panel, not the history list.
//  (Browsing lives in the ⌘⇧V popup / menu peek.)
//

import SwiftUI

struct ClipboardTabView: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings
    @State private var showingShortcuts = false
    @State private var showingIntro = false
    @State private var showingShowcase = false   // "What you get" showcase sheet
    @State private var showingReset = false
    @State private var showingClearAll = false
    @State private var imageBytes = 0
    // Reactive read — when the grant flips (watcher/activation), the tile + dimming auto-update.
    private var trusted: Bool { AccessibilityService.shared.isTrusted }
    /// Controls are live only when Accessibility is granted AND the module master is on.
    private var moduleActive: Bool { trusted && clipboard.isEnabled }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Divider()
                content
            }
        }
        .navigationTitle("Clipboard")
        .navigationSubtitle(storageSubtitle)
        // Native toolbar, two glass islands: learn/open · reset/destructive.
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingIntro = true } label: {
                    Label("How the clipboard works", systemImage: "info.circle")
                }
                .help("See how the clipboard popup works")
                Button { NotificationCenter.default.post(name: .openClipboardPopup, object: nil) } label: {
                    Label("Open the clipboard popup", systemImage: "doc.on.clipboard")
                }
                .help("Open the clipboard popup")
                .disabled(!moduleActive)
                Button { showingShortcuts.toggle() } label: {
                    Label("Keyboard shortcuts", systemImage: "keyboard")
                }
                .help("Keyboard shortcuts")
            }
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingReset = true } label: {
                    Label("Reset settings", systemImage: "arrow.counterclockwise")
                }
                .help("Reset clipboard settings to default — your items aren't affected")
                .disabled(!trusted)
                Button(role: .destructive) { showingClearAll = true } label: {
                    Label("Clear all clipboard items", systemImage: "trash")
                }
                .help("Clear all clipboard items")
                .disabled(itemCount == 0 || !trusted)
            }
        }
        .alert("Reset Clipboard settings to default?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                ConfigService.resetSettings(.clipboard)
                clipboard.reloadSettings()
            }
        } message: {
            Text("""
            These go back to default:
            • Enable & recording toggles
            • How many to keep (clipboard, menu, pins)
            • Row size, shortcut, restore-after-paste
            • Auto-clear, clear-on-quit, excluded apps

            Your clipboard items aren't affected.
            """)
        }
        .alert("Clear all clipboard items?", isPresented: $showingClearAll) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clipboard.clear()
                imageBytes = ImageStore.diskUsage()
            }
        } message: {
            Text("This permanently removes every item in your clipboard history. This can't be undone.")
        }
        .sheet(isPresented: $showingShortcuts) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Keyboard Shortcuts").font(.headline)
                ShortcutColumns()
                HStack {
                    Spacer()
                    Button("Done") { showingShortcuts = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingIntro) { ClipboardIntroSheet() }
        .sheet(isPresented: $showingShowcase) {
            ShowcaseSheet(title: "Clipboard", content: AnyView(ClipboardIntroView()))
        }
        .onAppear {
            imageBytes = ImageStore.diskUsage()
            AccessibilityService.shared.refresh()
            clipboard.updateScreenshotWatcher()   // re-resolve the folder in case the OS location changed
        }
    }

    // MARK: - Content

    private var content: some View {
        @Bindable var vm = settings
        // Tile appears only when Accessibility is off (nothing else is ever hidden).
        // (The full blocking overlay lives on the floating ⌘⇧V window, not this tab.)
        return VStack(alignment: .leading, spacing: 18) {
            if !trusted {
                PermissionTile(
                    icon: "doc.on.clipboard",
                    title: "Accessibility needed",
                    message: "Perch needs Accessibility to paste items for you. Your clipboard history still records without it.",
                    onGrant: { AccessibilityService.shared.request() },
                    onShowIntro: { showingShowcase = true })
            }
            // Master: interactive only when Accessibility is on; dimmed (not hidden) when off.
            ClipboardMasterGroup()
                .disabled(!trusted)
                .opacity(trusted ? 1 : 0.5)
            InfoNote(systemImage: "lock.fill", text: "Passwords and sensitive copies are never recorded.")
            ClipboardRecordingGroup()
            ClipboardScreenshotGroup()
            ClipboardLimitsGroup(menuItemCount: $vm.settings.menuItemCount)
            ClipboardAppearanceGroup()
            ClipboardBehaviorGroup()
            ClipboardPrivacyGroup()
            ClipboardExclusionsGroup()
        }
        .padding(20)
    }

    // MARK: - Data

    private var itemCount: Int {
        if case .loaded(let items) = clipboard.state { return items.count }
        return 0
    }

    /// "N items stored" — plus image storage used, when there is any.
    private var storageSubtitle: String {
        let items = "\(itemCount) item\(itemCount == 1 ? "" : "s") stored"
        guard imageBytes > 0 else { return items }
        let size = ByteCountFormatter.string(fromByteCount: Int64(imageBytes), countStyle: .file)
        return "\(items) · \(size) of images"
    }
}
