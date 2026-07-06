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

    @State private var accessibilityOK = AccessibilityService.shared.trusted
    @State private var monitoringOK = InputMonitoringService.shared.trusted

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Each tile shows only while ITS permission is missing (status re-read from the
            // services every time the dropdown opens).
            if !accessibilityOK {
                permissionTile(
                    title: "Accessibility needed",
                    detail: "Mouse, Keys, Scroll & quick paste are paused. Click to grant.",
                    request: { AccessibilityService.shared.request() }
                )
            }
            if !monitoringOK {
                permissionTile(
                    title: "Input Monitoring needed",
                    detail: "Mouse detection is paused. Click to grant.",
                    request: { InputMonitoringService.shared.request() }
                )
            }
            if clipboard.isEnabled {
                sectionHeader("Clipboard")
                ClipboardPeekView(onPick: app.menuPaste)
                Divider().padding(.vertical, 4)
            }

            if clipboard.isEnabled {
                menuButton("Open Clipboard", icon: "doc.on.clipboard", hint: settings.hotKeyDisplay) {
                    app.dismissMenu()
                    app.clipboardPanel.show()
                }
                menuButton("Open Snippets", icon: "text.quote") {
                    app.dismissMenu()
                    app.clipboardPanel.showSnippets()
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
            accessibilityOK = AccessibilityService.shared.trusted
            monitoringOK = InputMonitoringService.shared.trusted
        }
    }

    /// One warning tile per missing permission — the menu-bar icon is the app's ONLY
    /// always-visible surface, so this is where a user learns something is off.
    /// Click = system prompt + that permission's own System Settings pane.
    private func permissionTile(title: String, detail: String,
                                request: @escaping () -> Void) -> some View {
        Button {
            app.dismissMenu()
            request()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)   // wrap as needed
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
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
