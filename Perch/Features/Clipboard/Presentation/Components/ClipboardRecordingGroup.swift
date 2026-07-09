import SwiftUI

struct ClipboardRecordingGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }

    var body: some View {
        SettingGroup {
            SettingRow(title: "Save clipboard history",
                       subtitle: clipboard.isRecording ? "Recording copies" : "Paused — not recording",
                       icon: "clock.arrow.circlepath") {
                SwitchToggle(isOn: clipboard.isRecording) { clipboard.setRecording($0) }
                    .disabled(!moduleActive)
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }
}
