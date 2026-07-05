//
//  ScrollSection.swift
//  Perch
//
//  Menu-bar row: reverse-mouse-scroll toggle.
//

import SwiftUI

struct ScrollSection: View {
    @Environment(MouseViewModel.self) private var mouse

    var body: some View {
        MenuToggleRow(
            title: "Reverse mouse scroll",
            subtitle: mouse.needsPermission ? "Needs Accessibility permission" : "Trackpad untouched · All apps",
            subtitleColor: mouse.needsPermission ? .orange : .secondary,
            isOn: mouse.defaultScroll.reversed,
            onToggle: { mouse.updateDefaultScroll { $0.reversed.toggle() } }
        )
    }
}
