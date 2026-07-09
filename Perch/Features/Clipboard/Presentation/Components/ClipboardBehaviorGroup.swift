import SwiftUI

struct ClipboardBehaviorGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }

    var body: some View {
        SettingGroup("Behavior") {
            VStack(spacing: 10) {
                SettingRow(title: "Keyboard shortcut", subtitle: "Click the shortcut to record a new one.", icon: "keyboard") {
                    HotKeyRecorder(display: settings.hotKeyDisplay) { code, mods, label in
                        settings.setHotKey(code: code, modifiers: mods, label: label)
                    }
                }
                Divider()
                SettingRow(title: "Restore clipboard after paste",
                           subtitle: "Paste an item without changing your current clipboard.",
                           icon: "arrow.uturn.backward") {
                    SwitchToggle(isOn: clipboard.restoreAfterPaste) { clipboard.setRestoreAfterPaste($0) }
                }
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }
}
