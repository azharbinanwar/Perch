//
//  AppExcludeList.swift
//  Perch
//
//  Reusable editor for a list of apps (by bundle id): shows icon + name with
//  remove buttons, and an "Add app…" button that picks an app from disk.
//

import SwiftUI
import UniformTypeIdentifiers

struct AppExcludeList: View {
    let title: String
    let subtitle: String
    let bundleIDs: [String]
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }

            if bundleIDs.isEmpty {
                Text("No apps added").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                ForEach(bundleIDs, id: \.self) { id in
                    HStack(spacing: 6) {
                        if let icon = AppIcon.forBundleID(id) {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                        }
                        Text(AppIcon.name(forBundleID: id) ?? id).font(.system(size: 12))
                        Spacer()
                        Button { onRemove(id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button { pickApp() } label: {
                Label("Add app…", systemImage: "plus")
            }
            .font(.system(size: 11))
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier {
            onAdd(id)
        }
    }
}
