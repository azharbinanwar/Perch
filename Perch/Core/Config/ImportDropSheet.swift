//
//  ImportDropSheet.swift
//  Perch
//
//  The import entry point: drag a Perch Config file onto the zone, or browse for it.
//  A valid file flows straight into the section-picker (BackupSheet); an invalid one
//  gets the existing plain-language error alert. Standard 540×480 sheet.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportDropSheet: View {
    /// Called with the decoded config; the caller opens the section picker.
    let onDecoded: (PerchConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hovering = false   // a drag is over the zone — light it up

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Settings").font(.headline)
                Text("Drop a Perch Config file below, or browse for it — then pick what to bring in.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Divider()

            VStack(spacing: 14) {
                Image(systemName: hovering ? "arrow.down.doc.fill" : "arrow.down.doc")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(hovering ? Color.accentColor : .secondary)
                Text(hovering ? "Drop to import" : "Drop your Perch Config here")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(hovering ? Color.accentColor : .primary)
                Text("A .json file exported from Perch → General → Backup")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Button("Browse Files…") {
                    if let config = ConfigService.pickFileAndDecode() {
                        finish(config)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hovering ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(hovering ? Color.accentColor : Color.secondary.opacity(0.4),
                                  style: StrokeStyle(lineWidth: hovering ? 2 : 1.5, dash: [7]))
            )
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { decode(url) }
                }
                return true
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 540, height: 480)   // match the app's other sheets
    }

    private func decode(_ url: URL) {
        // Wrong kind of file (image, PDF…) → say that plainly, don't parse it as JSON.
        guard url.pathExtension.lowercased() == "json" else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "This file can't be imported"
            alert.informativeText = "Perch settings come as a .json file, exported from General > Backup. “\(url.lastPathComponent)” is a different kind of file.\n\nNothing was changed."
            alert.runModal()
            return
        }
        if let config = ConfigService.decodeFile(url) { finish(config) }
    }

    private func finish(_ config: PerchConfig) {
        dismiss()
        // Hand off after this sheet is gone so the section picker can present cleanly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDecoded(config) }
    }
}
