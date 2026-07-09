import SwiftUI

struct HyperKeyGroup: View {
    @Environment(RemapViewModel.self) private var vm
    @State private var introShowing = false

    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && vm.isEnabled }
    private var profileLabel: String { vm.isEditingDefault ? "All apps" : vm.editingProfileName }

    var body: some View {
        let symbols = vm.hyperShift ? "⌘⌥⌃⇧" : "⌘⌥⌃"
        SettingGroup("Hyper Key — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Enable Hyper Key",
                           subtitle: "Hold Caps Lock to act as \(symbols) together — a private shortcut layer no app conflicts with.",
                           icon: "capslock") {
                    HStack(spacing: 10) {
                        Button { introShowing = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16)).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless).help("See how the Hyper Key works")
                        Toggle("", isOn: Binding(get: { vm.hyperEnabled }, set: { vm.setHyperEnabled($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                if vm.hyperEnabled {
                    Divider()
                    SettingRow(title: "Single tap", subtitle: "A quick tap without another key.", icon: "1.circle") {
                        tapPicker(vm.hyperTap) { vm.setHyperTap($0) }
                    }
                    Divider()
                    SettingRow(title: "Double tap", subtitle: "Two quick taps in a row.", icon: "2.circle") {
                        tapPicker(vm.hyperDoubleTap) { vm.setHyperDoubleTap($0) }
                    }
                    Divider()
                    SettingRow(title: "Include ⇧ Shift",
                               subtitle: "Off sends ⌘⌥⌃ only — for the rare app that mishandles all four. Existing Hyper shortcuts update automatically.",
                               icon: "shift") {
                        Toggle("", isOn: Binding(get: { vm.hyperShift }, set: { vm.setHyperShift($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                    Label("Try it: hold Caps Lock and press M — apps see \(symbols)M, free for your own shortcuts.",
                          systemImage: "lightbulb")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .opacity(moduleActive ? 1 : 0.5)
        .disabled(!moduleActive)
        .sheet(isPresented: $introShowing) { HyperKeyIntroSheet() }
    }

    private func tapPicker(_ value: HyperKeyManager.TapAction,
                           onChange: @escaping (HyperKeyManager.TapAction) -> Void) -> some View {
        Picker("", selection: Binding(get: { value }, set: onChange)) {
            ForEach(HyperKeyManager.TapAction.allCases) { Text($0.rawValue).tag($0) }
        }
        .labelsHidden().frame(width: 130)
    }
}
