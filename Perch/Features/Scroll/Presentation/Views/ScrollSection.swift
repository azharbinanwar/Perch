//
//  ScrollSection.swift
//  Perch
//
//  Menu-bar row: reverse-mouse-scroll toggle.
//

import SwiftUI

struct ScrollSection: View {
    @Environment(ScrollViewModel.self) private var vm

    var body: some View {
        MenuToggleRow(
            title: "Reverse mouse scroll",
            subtitle: vm.needsPermission ? "Needs Accessibility permission" : "Trackpad untouched",
            subtitleColor: vm.needsPermission ? .orange : .secondary,
            isOn: vm.isEnabled,
            onToggle: vm.toggle
        )
    }
}
