import SwiftUI

struct ClipboardLimitsGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings
    @Binding var menuItemCount: Int

    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }
    private let clipboardSizeOptions: [Int] = [25, 50, 100, 200]
    private let menuSizeOptions = SettingsViewModel.menuCountOptions
    private let pinLimitOptions: [Int] = [5, 10, 15]

    var body: some View {
        SettingGroup("How many to keep") {
            VStack(spacing: 10) {
                SettingRow(title: "Clipboard", subtitle: "Items kept and shown in the \(settings.hotKeyDisplay) clipboard.", icon: "list.bullet") {
                    IntPicker(selection: Binding(get: { clipboard.maxItems }, set: { clipboard.setMaxItems($0) })) {
                        ForEach(clipboardSizeOptions, id: \.self) { Text("\($0) items").tag($0) }
                    }
                }
                Divider()
                SettingRow(title: "Menu", subtitle: "Items shown in the menu-bar peek.", icon: "menubar.rectangle") {
                    IntPicker(selection: $menuItemCount) {
                        ForEach(menuSizeOptions, id: \.self) { Text("\($0) items").tag($0) }
                    }
                }
                Divider()
                SettingRow(title: "Pins", subtitle: "Max items you can pin to the top.", icon: "pin") {
                    IntPicker(selection: Binding(get: { clipboard.pinLimit }, set: { clipboard.setPinLimit($0) })) {
                        ForEach(pinLimitOptions, id: \.self) { Text("\($0) pins").tag($0) }
                    }
                }
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }
}
