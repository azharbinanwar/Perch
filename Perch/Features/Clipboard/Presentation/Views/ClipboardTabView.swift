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
        @Bindable var vm = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                // Tile appears only when Accessibility is off (nothing else is ever hidden).
                // (The full blocking overlay lives on the floating ⌘⇧V window, not this tab.)
                if !trusted {
                    PermissionTile(
                        title: "Accessibility needed",
                        message: "Perch needs Accessibility to paste items for you. Your clipboard history still records without it.",
                        onGrant: { AccessibilityService.shared.request() },
                        onShowIntro: { showingShowcase = true })
                }
                // Master: interactive only when Accessibility is on; dimmed (not hidden) when off.
                masterGroup
                    .disabled(!trusted)
                    .opacity(trusted ? 1 : 0.5)
                InfoNote(systemImage: "lock.fill", text: "Passwords and sensitive copies are never recorded.")
                togglesBox
                limitsBox(vm: $vm.settings)
                appearanceBox
                behaviorBox
                privacyBox
                exclusionsBox
            }
            .padding(20)
        }
        .alert("Reset Clipboard settings to default?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Default") {
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
            Button("Clear All", role: .destructive) {
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
        .onAppear { imageBytes = ImageStore.diskUsage(); AccessibilityService.shared.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            PageHeader("Clipboard", subtitle: storageSubtitle)
            Spacer()
            HeaderIconButton(icon: "info.circle", help: "See how the clipboard popup works") {
                showingIntro = true
            }
            HeaderIconButton(icon: "doc.on.clipboard", help: "Open the clipboard popup") {
                NotificationCenter.default.post(name: .openClipboardPopup, object: nil)
            }
            .disabled(!moduleActive)
            HeaderIconButton(icon: "keyboard", help: "Keyboard shortcuts") {
                showingShortcuts.toggle()
            }
            HeaderIconButton(icon: "arrow.counterclockwise",
                             help: "Reset clipboard settings to default — your items aren't affected") {
                showingReset = true
            }
            .disabled(!trusted)
            HeaderIconButton(icon: "trash", help: "Clear all clipboard items", destructive: true) {
                showingClearAll = true
            }
            .disabled(itemCount == 0 || !trusted)
        }
    }

    // MARK: - Toggles (master + recording)

    private var masterGroup: some View {
        GroupBox {
            SettingRow(title: "Enable Clipboard",
                       subtitle: clipboard.isEnabled ? "\(settings.hotKeyDisplay) and menu peek are available"
                                                     : "Off — clipboard is hidden everywhere") {
                switchToggle(isOn: clipboard.isEnabled) { clipboard.setEnabled($0) }
            }
        }
    }

    private var togglesBox: some View {
        GroupBox {
            SettingRow(
                title: "Save clipboard history",
                subtitle: clipboard.isRecording ? "Recording copies" : "Paused — not recording"
            ) {
                switchToggle(isOn: clipboard.isRecording) { clipboard.setRecording($0) }
                    .disabled(!moduleActive)
            }
            .padding(6)
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    private func switchToggle(isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: action))
            .toggleStyle(.switch)
            .labelsHidden()
    }

    // MARK: - Privacy

    private let autoClearOptions: [(label: String, value: Int)] = [
        ("Never", 0), ("15 minutes", 15), ("1 hour", 60), ("6 hours", 360), ("24 hours", 1440)
    ]
    private let clipboardSizeOptions: [Int] = [25, 50, 100, 200]
    private let menuSizeOptions = SettingsViewModel.menuCountOptions
    private let pinLimitOptions: [Int] = [5, 10, 15]

    // MARK: - Limits

    private func limitsBox(vm: Binding<AppSettings>) -> some View {
        GroupBox("How many to keep") {
            VStack(spacing: 10) {
                SettingRow(title: "Clipboard", subtitle: "Items kept and shown in the \(settings.hotKeyDisplay) clipboard.") {
                    intPicker(selection: Binding(get: { clipboard.maxItems }, set: { clipboard.setMaxItems($0) })) {
                        ForEach(clipboardSizeOptions, id: \.self) { Text("\($0) items").tag($0) }
                    }
                }
                Divider()
                SettingRow(title: "Menu", subtitle: "Items shown in the menu-bar peek.") {
                    intPicker(selection: vm.menuItemCount) {
                        ForEach(menuSizeOptions, id: \.self) { Text("\($0) items").tag($0) }
                    }
                }
                Divider()
                SettingRow(title: "Pins", subtitle: "Max items you can pin to the top.") {
                    intPicker(selection: Binding(get: { clipboard.pinLimit }, set: { clipboard.setPinLimit($0) })) {
                        ForEach(pinLimitOptions, id: \.self) { Text("\($0) pins").tag($0) }
                    }
                }
            }
            .padding(6)
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    // MARK: - Appearance

    private var appearanceBox: some View {
        GroupBox("Appearance") {
            SettingRow(title: "Row size", subtitle: "How roomy each item is in the clipboard.") {
                Picker("", selection: Binding(get: { clipboard.rowDensity }, set: { clipboard.setRowDensity($0) })) {
                    ForEach(RowDensity.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            .padding(6)
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    // MARK: - Behavior

    private var behaviorBox: some View {
        GroupBox("Behavior") {
            VStack(spacing: 10) {
                SettingRow(title: "Keyboard shortcut", subtitle: "Click the shortcut to record a new one.") {
                    HotKeyRecorder(display: settings.hotKeyDisplay) { code, mods, label in
                        settings.setHotKey(code: code, modifiers: mods, label: label)
                    }
                }
                Divider()
                SettingRow(title: "Restore clipboard after paste",
                           subtitle: "Paste an item without changing your current clipboard.") {
                    switchToggle(isOn: clipboard.restoreAfterPaste) { clipboard.setRestoreAfterPaste($0) }
                }
            }
            .padding(6)
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    // MARK: - Privacy

    private var privacyBox: some View {
        GroupBox("Privacy") {
            VStack(spacing: 10) {
                SettingRow(title: "Auto-clear history", subtitle: "Remove copies older than the selected time.") {
                    intPicker(selection: Binding(get: { clipboard.autoClearMinutes }, set: { clipboard.setAutoClear($0) })) {
                        ForEach(autoClearOptions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                }
                Divider()
                SettingRow(title: "Clear history on quit", subtitle: "Wipe everything when Perch quits.") {
                    switchToggle(isOn: clipboard.clearOnQuit) { clipboard.setClearOnQuit($0) }
                }
            }
            .padding(6)
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    // MARK: - Excluded apps (two separate lists)

    private var exclusionsBox: some View {
        GroupBox("Excluded apps") {
            VStack(alignment: .leading, spacing: 12) {
                AppExcludeList(
                    title: "Don't record here",
                    subtitle: "Copies made while these apps are focused aren't saved.",
                    bundleIDs: clipboard.excludedRecordApps,
                    onAdd: clipboard.addExcludedRecordApp,
                    onRemove: clipboard.removeExcludedRecordApp
                )
                Divider()
                AppExcludeList(
                    title: "Don't open here",
                    subtitle: "\(settings.hotKeyDisplay) won't open while these apps are focused.",
                    bundleIDs: clipboard.excludedOpenApps,
                    onAdd: clipboard.addExcludedOpenApp,
                    onRemove: clipboard.removeExcludedOpenApp
                )
            }
            .padding(6)
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    private func intPicker<Content: View>(selection: Binding<Int>,
                                          @ViewBuilder content: () -> Content) -> some View {
        Picker("", selection: selection) { content() }
            .labelsHidden()
            .frame(width: 130)
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
