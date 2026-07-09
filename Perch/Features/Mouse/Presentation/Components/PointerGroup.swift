import SwiftUI

struct PointerGroup: View {
    @Environment(MouseViewModel.self) private var mouse
    private var profileLabel: String { mouse.isEditingDefault ? "All apps" : mouse.editingProfileName }

    var body: some View {
        SettingGroup("Pointer — \(profileLabel)") {
            VStack(spacing: 10) {
                SettingRow(title: "Control pointer acceleration",
                           subtitle: "Override macOS cursor acceleration — off leaves the system default.",
                           icon: "cursorarrow.motionlines") {
                    SwitchToggle(isOn: mouse.editingPointer.override) { on in mouse.updatePointer { $0.override = on } }
                }
                if mouse.editingPointer.override {
                    Divider()
                    SettingRow(title: "Acceleration", subtitle: "0 = flat 1:1 tracking; higher = more.") {
                        ValueSlider(value: mouse.editingPointer.value, range: 0...20, step: 0.5, format: "%.1f") { v in
                            mouse.updatePointer { $0.value = v }
                        }
                    }
                }
            }
        }
    }
}
