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
    @State private var importingFile = false   // the drag-and-drop / browse entry sheet

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

            GroupBox("Appearance") {
                SettingRow(title: "Theme",
                           subtitle: "System follows macOS; Light or Dark forces it everywhere in Perch.") {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { themeSwatch($0) }
                    }
                }
                .padding(6)
            }

            GroupBox("Permissions") {
                VStack(spacing: 10) {
                    permissionRow(
                        title: "Accessibility",
                        subtitle: "Controls input — Mouse, Keys, Scroll & quick clipboard paste.",
                        granted: AccessibilityService.shared.trusted,
                        grant: { AccessibilityService.shared.request() }
                    )
                    Divider()
                    permissionRow(
                        title: "Input Monitoring",
                        subtitle: "Observes devices — mouse detection and key watching.",
                        granted: InputMonitoringService.shared.trusted,
                        grant: { InputMonitoringService.shared.request() }
                    )
                }
                .padding(6)
            }

            GroupBox("Backup") {
                SettingRow(title: "Export or import settings",
                           subtitle: "Pick exactly which sections to save, or bring in — the rest stay as they are.") {
                    HStack(spacing: 8) {
                        Button("Export…") { backup = BackupRequest(mode: .export, config: ConfigService.export()) }
                        Button("Import…") { importingFile = true }
                    }
                }
                .padding(6)
            }

            GroupBox("About") {
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
                .padding(6)
            }

            // SafetyTimerBox()   // hidden for now — re-enable when we need the safety timer

            // Debug log — kept for future engine debugging; uncomment to show it again.
            // GroupBox("Debug log") {
            //     VStack(alignment: .leading, spacing: 8) {
            //         ScrollViewReader { proxy in
            //             ScrollView {
            //                 Text(DiagLog.shared.text.isEmpty ? "Engine diagnostics appear here." : DiagLog.shared.text)
            //                     .font(.system(size: 11, design: .monospaced))
            //                     .textSelection(.enabled)
            //                     .frame(maxWidth: .infinity, alignment: .leading)
            //                     .id("logEnd")
            //             }
            //             .frame(height: 320)
            //             .onChange(of: DiagLog.shared.text) { _, _ in
            //                 proxy.scrollTo("logEnd", anchor: .bottom)   // always follow the newest line
            //             }
            //         }
            //         HStack {
            //             Spacer()
            //             Button("Clear") { DiagLog.shared.clear() }
            //                 .disabled(DiagLog.shared.text.isEmpty)
            //             Button("Copy") {
            //                 NSPasteboard.general.clearContents()
            //                 NSPasteboard.general.setString(DiagLog.shared.text, forType: .string)
            //             }
            //             .disabled(DiagLog.shared.text.isEmpty)
            //         }
            //     }
            //     .padding(6)
            // }

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
                    reloadViewModels()   // refresh live via the injected VMs — no AppDelegate lookup
                }
            }
        }
    }

    /// Re-read storage into the view models already injected into this screen.
    private func reloadViewModels() {
        settings.reload()
        remap.reload()
        mouse.reload()               // buttons, gestures, scroll AND pointer (per-app profiles)
        snippet.reload()
        clipboard.reloadSettings()   // limits, toggles, exclusions — applied live
        clipboard.reloadHistory()    // the saved item list (system clipboard untouched)
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden()
    }

    /// One permission line: status icon + name/what-it-powers + Grant only while it's missing.
    private func permissionRow(title: String, subtitle: String, granted: Bool,
                               grant: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant…") { grant() }.buttonStyle(.borderedProminent)
            }
        }
    }

    /// A mini window preview per theme — System split diagonally, Light white, Dark black —
    /// with an accent ring on the selected one (same visual as CleanKit's picker).
    private func themeSwatch(_ theme: AppTheme) -> some View {
        let selected = settings.settings.theme == theme
        return Button { settings.settings.theme = theme } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(swatchBackground(theme))
                        .frame(width: 58, height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                                    lineWidth: selected ? 2 : 1))
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme == .dark ? Color.white.opacity(0.15)
                                  : theme == .light ? Color.black.opacity(0.08) : Color.gray.opacity(0.45))
                            .frame(width: 13, height: 26)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme == .dark ? Color.white.opacity(0.08)
                                  : theme == .light ? Color.black.opacity(0.04) : Color.gray.opacity(0.25))
                            .frame(width: 30, height: 26)
                    }
                }
                Text(theme.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func swatchBackground(_ theme: AppTheme) -> AnyShapeStyle {
        switch theme {
        case .light: return AnyShapeStyle(Color.white)
        case .dark:  return AnyShapeStyle(Color.black)
        case .system:
            return AnyShapeStyle(LinearGradient(
                stops: [.init(color: .black, location: 0.499), .init(color: .white, location: 0.501)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}
