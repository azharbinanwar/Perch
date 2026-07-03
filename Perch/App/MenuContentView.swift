//
//  MenuContentView.swift
//  Perch
//
//  Menu-bar dropdown: clipboard peek + feature toggles + Open/Quit.
//

import SwiftUI

struct MenuContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings
    let app: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if clipboard.isEnabled {
                sectionHeader("Clipboard")
                ClipboardPeekView(onPick: app.menuPaste)
                Divider().padding(.vertical, 4)
            }

            sectionHeader("Toggles")
            ClipboardEnableToggleRow()
            if clipboard.isEnabled { ClipboardSaveToggleRow() }
            // Scroll & Remap toggles land here once those features ship.

            Divider().padding(.vertical, 4)

            if clipboard.isEnabled {
                menuButton("Open Clipboard", icon: "doc.on.clipboard", hint: settings.hotKeyDisplay) {
                    app.dismissMenu()
                    app.clipboardPanel.show()
                }
            }
            menuButton("Open Perch…", icon: "macwindow") {
                app.dismissMenu()
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            menuButton("Quit Perch", icon: "power") {
                NSApp.terminate(nil)
            }
        }
        .frame(width: 280)
        .padding(.vertical, 6)
        .onAppear {
            app.captureMenuContext()
            app.openWindowAction = { openWindow(id: $0) }
        }
    }

    private func sectionHeader(_ title: String, hint: String? = nil) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            Spacer()
            if let hint {
                Text(hint)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 3)
    }

    private func menuButton(_ title: String, icon: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon).font(.system(size: 12))
                Spacer()
                if let hint {
                    Text(hint).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
