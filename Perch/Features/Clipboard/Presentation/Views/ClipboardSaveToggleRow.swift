//
//  ClipboardSaveToggleRow.swift
//  Perch
//
//  Menu-bar row: pause/resume recording copies. History is kept when paused.
//

import SwiftUI

struct ClipboardSaveToggleRow: View {
    @Environment(ClipboardViewModel.self) private var vm

    var body: some View {
        MenuToggleRow(
            title: "Save clipboard history",
            isOn: vm.isRecording,
            onToggle: vm.toggleRecording
        )
    }
}
