//
//  RemapToggleRow.swift
//  Perch
//
//  Menu-bar row: on/off toggle. Editing lives in the Keys tab.
//

import SwiftUI

struct RemapToggleRow: View {
    @Environment(RemapViewModel.self) private var vm

    var body: some View {
        MenuToggleRow(
            title: "Ctrl → Cmd remap",
            subtitle: vm.needsPermission ? "Needs Accessibility permission" : "External keyboard",
            subtitleColor: vm.needsPermission ? .orange : .secondary,
            isOn: vm.isEnabled,
            onToggle: vm.toggleEnabled
        )
    }
}
