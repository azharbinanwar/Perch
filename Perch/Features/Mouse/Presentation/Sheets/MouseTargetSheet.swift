//
//  MouseTargetSheet.swift
//  Perch
//

import SwiftUI

struct MappingTarget: Identifiable {
    let id = UUID()
    let trigger: MouseTrigger
    let phase: ClickPhase
    let kind: ActionKind
    var layerHold: MouseTrigger? = nil   // set → the picked action lands in THIS shift key's combos
}

struct MouseTargetSheet: View {
    @Environment(MouseViewModel.self) private var mouse
    let prompt: MappingTarget

    var body: some View {
        switch prompt.kind.target {
        case .app:
            AppPickerSheet(allowsMultipleSelection: false) { ids in
                if let bundle = ids.first { set(Action(kind: .openApp, target: bundle)) }
            }
        case .keystroke:
            KeystrokeCaptureSheet { code, mods in
                set(Action(kind: .customKeystroke, keyCode: Int(code), modifiers: mods))
            }
        case .url:
            TextTargetSheet(title: "Open URL", placeholder: "https://…") { set(Action(kind: .openURL, target: $0)) }
        case .file:
            TextTargetSheet(title: "Open File or Folder", placeholder: "/Users/…/file", allowFilePicker: true) { set(Action(kind: .openFile, target: $0)) }
        case .shellScript:
            PresetPickerSheet(title: "Run Shell Script", customPlaceholder: "echo hello", load: { ActionPresets.shell }) { set(Action(kind: .runShell, target: $0)) }
        case .appleScript:
            PresetPickerSheet(title: "Run AppleScript", customPlaceholder: "display dialog \"Hi\"", load: { ActionPresets.appleScript }) { set(Action(kind: .runAppleScript, target: $0)) }
        default:
            EmptyView()
        }
    }

    private func set(_ action: Action) {
        if let hold = prompt.layerHold {
            mouse.setLayerAction(action, hold: hold, for: prompt.trigger, phase: prompt.phase)
        } else {
            mouse.setAction(action, for: prompt.trigger, phase: prompt.phase)
        }
    }
}
