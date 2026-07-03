//
//  MouseTargetSheets.swift
//  Perch
//
//  Small prompts for actions that need a target: a keystroke to fire, or a URL/file to open.
//  (App picking reuses the shared AppPickerSheet.)
//

import SwiftUI

/// Record a key combo for a "Custom Keystroke" action — swallows the keys while recording, so
/// pressing e.g. ⌘⇧4 is captured instead of firing the screenshot.
struct KeystrokeCaptureSheet: View {
    let onCapture: (UInt32, UInt64) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = KeyChordRecorder()

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "keyboard").font(.system(size: 28)).foregroundStyle(.secondary)
            Text("Press the keys to record").font(.headline)
            Text("The combo is captured, not triggered. Press Esc to cancel.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 340)
        .onAppear {
            recorder.onCapture = { code, mods in
                onCapture(UInt32(code), mods)
                dismiss()
            }
            recorder.start()
        }
        .onDisappear { recorder.stop() }
    }
}

/// Enter a URL or file/folder path for an "Open…" action.
struct TextTargetSheet: View {
    let isFile: Bool
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isFile ? "Open File or Folder" : "Open URL").font(.headline)
            TextField(isFile ? "/Users/…/file" : "https://…", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                if isFile {
                    Button("Choose…") { chooseFile() }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func submit() {
        guard !text.isEmpty else { return }
        onSubmit(text)
        dismiss()
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            text = url.path
        }
    }
}
