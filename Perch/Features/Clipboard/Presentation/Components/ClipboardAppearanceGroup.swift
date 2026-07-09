import SwiftUI

struct ClipboardAppearanceGroup: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && clipboard.isEnabled }

    var body: some View {
        SettingGroup("Appearance") {
            SettingRow(title: "Row size", subtitle: "How roomy each item is in the clipboard.", icon: "arrow.up.and.down.text.horizontal") {
                Picker("", selection: Binding(get: { clipboard.rowDensity }, set: { clipboard.setRowDensity($0) })) {
                    ForEach(RowDensity.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 130)
            }
        }
        .disabled(!moduleActive)
        .opacity(moduleActive ? 1 : 0.5)
    }
}
