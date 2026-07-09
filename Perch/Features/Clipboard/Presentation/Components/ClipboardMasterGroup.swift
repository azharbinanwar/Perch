import SwiftUI

struct ClipboardMasterGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        SettingGroup {
            SettingRow(title: "Enable Clipboard",
                       subtitle: clipboard.isEnabled ? "\(settings.hotKeyDisplay) and menu peek are available"
                                                     : "Off — clipboard is hidden everywhere",
                       icon: "doc.on.clipboard") {
                SwitchToggle(isOn: clipboard.isEnabled) { clipboard.setEnabled($0) }
            }
        }
    }
}
