import SwiftUI

struct ClipboardExclusionsGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }

    var body: some View {
        SettingGroup("Excluded apps") {
            VStack(alignment: .leading, spacing: 12) {
                AppExcludeList(
                    title: "Don't record here",
                    subtitle: "Copies made while these apps are focused aren't saved.",
                    icon: "eye.slash",
                    bundleIDs: clipboard.excludedRecordApps,
                    onAdd: clipboard.addExcludedRecordApp,
                    onRemove: clipboard.removeExcludedRecordApp
                )
                Divider()
                AppExcludeList(
                    title: "Don't open here",
                    subtitle: "\(settings.hotKeyDisplay) won't open while these apps are focused.",
                    icon: "rectangle.slash",
                    bundleIDs: clipboard.excludedOpenApps,
                    onAdd: clipboard.addExcludedOpenApp,
                    onRemove: clipboard.removeExcludedOpenApp
                )
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }
}
