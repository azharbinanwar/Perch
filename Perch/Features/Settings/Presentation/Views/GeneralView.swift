//
//  GeneralView.swift
//  Perch
//

import SwiftUI

struct GeneralView: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var vm = settings
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

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden()
    }
}
