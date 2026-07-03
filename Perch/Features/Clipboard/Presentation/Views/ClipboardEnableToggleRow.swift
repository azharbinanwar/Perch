//
//  ClipboardEnableToggleRow.swift
//  Perch
//
//  Menu-bar row: master switch for the whole clipboard feature.
//

import SwiftUI

struct ClipboardEnableToggleRow: View {
    @Environment(ClipboardViewModel.self) private var vm

    var body: some View {
        MenuToggleRow(
            title: "Enable clipboard",
            isOn: vm.isEnabled,
            onToggle: vm.toggleEnabled
        )
    }
}
