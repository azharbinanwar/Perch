//
//  GeneralView.swift
//  Perch
//

import SwiftUI

struct GeneralView: View {
    @Environment(SettingsViewModel.self) private var settings
    @Environment(RemapViewModel.self) private var remap
    @Environment(MouseViewModel.self) private var mouse
    @Environment(SnippetViewModel.self) private var snippet
    @Environment(ClipboardViewModel.self) private var clipboard

    @State private var backup: BackupRequest?
    @State private var importingFile = false
    @State private var devTaps = 0
    @State private var showDev = false        // 7 taps on the title; resets each launch

    var body: some View {
        @Bindable var vm = settings
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader("General", subtitle: "Startup, permissions, and how Perch behaves.")
                .contentShape(Rectangle())
                .onTapGesture { devTaps += 1; if devTaps >= 7 { showDev = true } }

            SettingGroup("Permissions") {
                VStack(spacing: 10) {
                    PermissionStatusRow(
                        icon: "accessibility",
                        title: "Accessibility",
                        subtitle: "Controls input — Mouse, Keys, Scroll & quick clipboard paste.",
                        granted: AccessibilityService.shared.isTrusted,
                        grant: { AccessibilityService.shared.request() })
                    Divider()
                    PermissionStatusRow(
                        icon: "dot.viewfinder",
                        title: "Input Monitoring",
                        subtitle: "Observes devices — mouse detection and key watching.",
                        granted: InputMonitoringService.shared.isTrusted,
                        grant: { InputMonitoringService.shared.request() })
                }
            }

            SettingGroup("Startup") {
                VStack(spacing: 10) {
                    SettingRow(title: "Launch at login",
                               subtitle: "Start Perch automatically when you log in.",
                               icon: "power") {
                        toggle($vm.settings.openAtLogin)
                    }
                    Divider()
                    SettingRow(title: "Open window at launch",
                               subtitle: "Show this window on start — otherwise Perch stays in the menu bar.",
                               icon: "macwindow") {
                        toggle($vm.settings.openWindowAtLaunch)
                    }
                    Divider()
                    SettingRow(title: "Show in Dock",
                               subtitle: "Also keep a Dock icon. Off keeps Perch menu-bar only.",
                               icon: "dock.rectangle") {
                        toggle($vm.settings.showInDock)
                    }
                }
            }

            SettingGroup("Appearance") {
                SettingRow(title: "Theme",
                           subtitle: "System follows macOS; Light or Dark forces it everywhere in Perch.",
                           icon: "paintbrush") {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { ThemeSwatch(theme: $0) }
                    }
                }
            }

            SettingGroup("Backup") {
                SettingRow(title: "Export or import settings",
                           subtitle: "Pick exactly which sections to save, or bring in — the rest stay as they are.",
                           icon: "arrow.up.arrow.down") {
                    HStack(spacing: 8) {
                        Button("Export…") { backup = BackupRequest(mode: .export, config: ConfigService.export()) }
                        Button("Import…") { importingFile = true }
                    }
                }
            }

            SettingGroup("About") {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image("perch").resizable().scaledToFit()
                            .frame(width: 34, height: 34)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                                 ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Perch")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Divider()
                    UpdateSection()
                }
            }

            if showDev {
                SafetyTimerBox()
                DebugLogBox()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $importingFile) {
            ImportDropSheet { config in
                backup = BackupRequest(mode: .importing, config: config)
            }
        }
        .sheet(item: $backup) { req in
            BackupSheet(mode: req.mode, config: req.config) { sections in
                switch req.mode {
                case .export:
                    ConfigService.writeToFile(ConfigService.keepingOnly(sections, of: req.config))
                case .importing:
                    ConfigService.apply(req.config, sections: sections)
                    reloadViewModels()
                }
            }
        }
    }

    private func reloadViewModels() {
        settings.reload()
        remap.reload()
        mouse.reload()
        snippet.reload()
        clipboard.reloadSettings()
        clipboard.reloadHistory()
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden()
    }
}
