//
//  MappingCaptureSheet.swift
//  Perch
//

import SwiftUI

struct MappingCaptureSheet: View {
    @Environment(RemapViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var targetPrompt: ActionKind?

    var body: some View {
        let editing = vm.editingRuleID != nil
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(editing ? "Edit mapping" : "Add mapping").font(.headline)
                Text("Press a key or shortcut, then choose what it does.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                RecordField(
                    label: "FROM",
                    text: vm.recording == .input ? "Recording — press keys now" : (vm.draftInput?.displayName ?? "Click to record"),
                    active: vm.recording == .input,
                    placeholder: vm.draftInput == nil && vm.recording != .input,
                    hint: vm.recording == .input ? "Press the key or shortcut you want to change."
                                                 : "Click the box, then press a key or shortcut.",
                    onTap: { toggleRecord(.input) })

                Image(systemName: "arrow.down").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center)

                RecordField(
                    label: "TO",
                    text: vm.recording == .output ? "Recording — press keys now" : (vm.draftOutput?.displayLabel ?? "Click to record a key"),
                    active: vm.recording == .output,
                    placeholder: vm.draftOutput == nil && vm.recording != .output,
                    hint: vm.recording == .output ? "Press the key or shortcut it should become."
                                                  : "Click the box to record a key, or use the grid to pick an action.",
                    onTap: { toggleRecord(.output) }
                ) {
                    Button { vm.cancelRecording(); picking = true } label: {   // stop recording, then pick
                        Image(systemName: "square.grid.2x2").font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Pick a ready-made action")
                }

                if let input = vm.draftInput, vm.draftOutput != nil,
                   vm.rules.contains(where: { $0.input == input && $0.id != vm.editingRuleID }) {
                    Label("\(input.displayName) is already mapped.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(editing ? "Save" : "Add") { vm.addDraft(); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(!vm.canAddDraft)
            }
            .padding(16)
        }
        .frame(width: 540)
        .onAppear { if vm.editingRuleID == nil { vm.clearDraft(); vm.record(.input) } }   // add: auto-record · edit: keep prefill
        .sheet(isPresented: $picking) {
            ActionPicker(excluding: [.passThrough]) { kind in
                if kind.target == .none { vm.setOutputAction(Action(kind: kind)) }
                else { targetPrompt = kind }
            }
        }
        .sheet(item: $targetPrompt) { targetSheet($0) }
    }

    /// Click a box to start recording; click it again (while recording) to cancel.
    private func toggleRecord(_ field: RemapField) {
        if vm.recording == field { vm.cancelRecording() } else { vm.record(field) }
    }

    @ViewBuilder
    private func targetSheet(_ kind: ActionKind) -> some View {
        switch kind.target {
        case .app:
            AppPickerSheet(allowsMultipleSelection: false) { ids in if let b = ids.first { vm.setOutputAction(Action(kind: .openApp, target: b)) } }
        case .keystroke:
            KeystrokeCaptureSheet { code, mods in
                vm.setOutputAction(Action(kind: .customKeystroke, keyCode: Int(code), modifiers: mods))
            }
        case .url:
            TextTargetSheet(title: "Open URL", placeholder: "https://…") { vm.setOutputAction(Action(kind: .openURL, target: $0)) }
        case .file:
            TextTargetSheet(title: "Open File or Folder", placeholder: "/Users/…/file", allowFilePicker: true) { vm.setOutputAction(Action(kind: .openFile, target: $0)) }
        case .shellScript:
            PresetPickerSheet(title: "Run Shell Script", customPlaceholder: "echo hello", load: { ActionPresets.shell }) { vm.setOutputAction(Action(kind: .runShell, target: $0)) }
        case .appleScript:
            PresetPickerSheet(title: "Run AppleScript", customPlaceholder: "display dialog \"Hi\"", load: { ActionPresets.appleScript }) { vm.setOutputAction(Action(kind: .runAppleScript, target: $0)) }
        default:
            EmptyView()
        }
    }
}
