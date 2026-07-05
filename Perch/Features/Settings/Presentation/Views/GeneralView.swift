//
//  GeneralView.swift
//  Perch
//

import SwiftUI

struct GeneralView: View {
    @Environment(SettingsViewModel.self) private var settings
    @Environment(RemapViewModel.self) private var remap
    @Environment(MouseViewModel.self) private var mouse
    @Environment(ScrollViewModel.self) private var scroll
    @Environment(PointerViewModel.self) private var pointer
    @Environment(SnippetViewModel.self) private var snippet
    @Environment(ClipboardViewModel.self) private var clipboard

    @State private var backup: BackupRequest?

    var body: some View {
        @Bindable var vm = settings
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader("General", subtitle: "Startup, permissions, and how Perch behaves.")

            GroupBox("Startup") {
                VStack(spacing: 10) {
                    SettingRow(title: "Launch at login",
                               subtitle: "Start Perch automatically when you log in.") {
                        toggle($vm.settings.openAtLogin)
                    }
                    Divider()
                    SettingRow(title: "Open window at launch",
                               subtitle: "Show this window on start — otherwise Perch stays in the menu bar.") {
                        toggle($vm.settings.openWindowAtLaunch)
                    }
                    Divider()
                    SettingRow(title: "Show in Dock",
                               subtitle: "Also keep a Dock icon. Off keeps Perch menu-bar only.") {
                        toggle($vm.settings.showInDock)
                    }
                }
                .padding(6)
            }

            GroupBox("Permissions") {
                HStack {
                    Image(systemName: Permissions.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(Permissions.isAccessibilityTrusted ? .green : .orange)
                    Text(Permissions.isAccessibilityTrusted
                         ? "Accessibility granted — Mouse, Keys, Scroll & quick clipboard paste can run."
                         : "Accessibility needed for Mouse, Keys, Scroll & quick clipboard paste.")
                        .font(.system(size: 13))
                    Spacer()
                    if !Permissions.isAccessibilityTrusted {
                        Button("Grant…") { Permissions.requestAccessibility() }
                    }
                }
                .padding(6)
            }

            GroupBox("Backup") {
                SettingRow(title: "Export or import settings",
                           subtitle: "Pick exactly which sections to save, or bring in — the rest stay as they are.") {
                    HStack(spacing: 8) {
                        Button("Export…") { backup = BackupRequest(mode: .export, config: ConfigService.export()) }
                        Button("Import…") {
                            if let config = ConfigService.pickFileAndDecode() {
                                backup = BackupRequest(mode: .importing, config: config)
                            }
                        }
                    }
                }
                .padding(6)
            }

        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $backup) { req in
            BackupSheet(mode: req.mode, config: req.config) { sections in
                switch req.mode {
                case .export:
                    ConfigService.writeToFile(ConfigService.keepingOnly(sections, of: req.config))
                case .importing:
                    ConfigService.apply(req.config, sections: sections)
                    reloadViewModels()   // refresh live via the injected VMs — no AppDelegate lookup
                }
            }
        }
    }

    /// Re-read storage into the view models already injected into this screen.
    private func reloadViewModels() {
        settings.reload()
        remap.reload()
        mouse.reload()
        scroll.reload()
        pointer.reload()
        snippet.reload()
        clipboard.reloadSettings()   // limits, toggles, exclusions — applied live
        clipboard.reloadHistory()    // the saved item list (system clipboard untouched)
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden()
    }
}
