import SwiftUI
import AppKit

struct ClipboardScreenshotGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }

    var body: some View {
        SettingGroup("Screenshots") {
            VStack(spacing: 10) {
                SettingRow(title: "Save screenshots to clipboard",
                           subtitle: "New screenshots are added to your clipboard history automatically.",
                           icon: "camera.viewfinder") {
                    SwitchToggle(isOn: clipboard.screenshotsToClipboard) { clipboard.setScreenshotsToClipboard($0) }
                }
                if clipboard.screenshotsToClipboard {
                    Divider()
                    SettingRow(title: "Watched folder",
                               subtitle: shortPath(clipboard.screenshotFolder),
                               icon: "folder", indented: true) {
                        Button("Change…") { pickFolder() }
                    }
                    InfoNote(systemImage: "lightbulb",
                             text: "For instant capture, turn off the screenshot floating thumbnail (⌘⇧5 → Options).")
                }
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }

    private func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: clipboard.screenshotFolder)
        panel.prompt = "Watch"
        if panel.runModal() == .OK, let url = panel.url {
            clipboard.setScreenshotFolder(url.path)   // user pick also grants access to that folder
        }
    }
}
