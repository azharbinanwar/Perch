//
//  ClipboardEnableToggleRow.swift
//  Perch
//
//  Menu-bar row: master switch for the whole clipboard feature.
//

import SwiftUI

struct ClipboardEnableToggleRow: View {
    @Environment(ClipboardViewModel.self) private var vm
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        MenuToggleRow(
            title: "Enable clipboard",
            subtitle: vm.isEnabled ? "\(settings.hotKeyDisplay) and peek available" : "Off — hidden everywhere",
            isOn: vm.isEnabled,
            onToggle: vm.toggleEnabled
        )
    }
}
