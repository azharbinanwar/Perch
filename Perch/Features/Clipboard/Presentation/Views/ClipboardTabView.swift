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
    @State private var imageBytes = 0

    var body: some View {
        @Bindable var vm = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
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
        .onAppear { imageBytes = ImageStore.diskUsage() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            PageHeader("Clipboard", subtitle: storageSubtitle)
            Spacer()
            Button {
                NotificationCenter.default.post(name: .openClipboardPopup, object: nil)
            } label: {
                Label("Open", systemImage: "doc.on.clipboard")
            }
            .disabled(!clipboard.isEnabled)

            Button { showingShortcuts.toggle() } label: {
                Label("Shortcuts", systemImage: "keyboard")
            }
            .help("Keyboard shortcuts")

            Button(role: .destructive) {
                clipboard.clear()
                imageBytes = ImageStore.diskUsage()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .disabled(itemCount == 0)
        }
    }

    // MARK: - Toggles (master + recording)

    private var togglesBox: some View {
        GroupBox {
            VStack(spacing: 10) {
                SettingRow(
                    title: "Enable clipboard",
                    subtitle: clipboard.isEnabled ? "\(settings.hotKeyDisplay) and menu peek are available" : "Off — clipboard is hidden everywhere"
                ) {
                    switchToggle(isOn: clipboard.isEnabled) { clipboard.setEnabled($0) }
                }
                Divider()
                SettingRow(
                    title: "Save clipboard history",
                    subtitle: clipboard.isRecording ? "Recording copies" : "Paused — not recording"
                ) {
                    switchToggle(isOn: clipboard.isRecording) { clipboard.setRecording($0) }
                        .disabled(!clipboard.isEnabled)
                }
                .opacity(clipboard.isEnabled ? 1 : 0.5)
            }
            .padding(6)
        }
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
        .disabled(!clipboard.isEnabled)
        .opacity(clipboard.isEnabled ? 1 : 0.5)
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
        .disabled(!clipboard.isEnabled)
        .opacity(clipboard.isEnabled ? 1 : 0.5)
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
        .disabled(!clipboard.isEnabled)
        .opacity(clipboard.isEnabled ? 1 : 0.5)
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
        .disabled(!clipboard.isEnabled)
        .opacity(clipboard.isEnabled ? 1 : 0.5)
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
        .disabled(!clipboard.isEnabled)
        .opacity(clipboard.isEnabled ? 1 : 0.5)
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
