import SwiftUI

struct ClipboardPrivacyGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }
    private let autoClearOptions: [(label: String, value: Int)] = [
        ("Never", 0), ("15 minutes", 15), ("1 hour", 60), ("6 hours", 360), ("24 hours", 1440)
    ]

    var body: some View {
        SettingGroup("Privacy") {
            VStack(spacing: 10) {
                SettingRow(title: "Auto-clear history", subtitle: "Remove copies older than the selected time.", icon: "clock.badge.xmark") {
                    IntPicker(selection: Binding(get: { clipboard.autoClearMinutes }, set: { clipboard.setAutoClear($0) })) {
                        ForEach(autoClearOptions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                }
                Divider()
                SettingRow(title: "Clear history on quit", subtitle: "Wipe everything when Perch quits.", icon: "trash") {
                    SwitchToggle(isOn: clipboard.clearOnQuit) { clipboard.setClearOnQuit($0) }
                }
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }
}
