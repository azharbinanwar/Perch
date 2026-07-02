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
            Text("General").font(.title2.bold())

            GroupBox {
                Toggle("Launch Perch at login", isOn: $vm.settings.openAtLogin)
                    .padding(6)
            }

            GroupBox("Permissions") {
                HStack {
                    Image(systemName: Permissions.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(Permissions.isAccessibilityTrusted ? .green : .orange)
                    Text(Permissions.isAccessibilityTrusted
                         ? "Accessibility granted — Scroll & Remap can run."
                         : "Accessibility needed for Scroll & Remap.")
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
}
