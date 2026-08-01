import SwiftUI

// The list of key mappings for the current profile. Editing a row calls back to the tab, which
// owns the capture sheet.
struct ShortcutsGroup: View {
    @Environment(RemapViewModel.self) private var vm
    let onEdit: (RemapRule) -> Void

    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && vm.isEnabled }
    private var profileLabel: String { vm.isEditingDefault ? "All apps" : vm.editingProfileName }

    var body: some View {
        SettingGroup("Shortcuts — \(profileLabel)") {
            Group {
                if vm.rules.isEmpty {
                    Text("No mappings yet — add one with “Add mapping”.")
                        .font(.system(size: 12)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.rules.enumerated()), id: \.element.id) { index, rule in
                            if index > 0 { Divider() }
                            RemapRuleRow(rule: rule, onEdit: { onEdit(rule) })
                        }
                    }
                }
            }
            .opacity(moduleActive ? 1 : 0.5)
        }
    }
}

// One mapping: enable toggle · input → output (tap to edit) · delete.
struct RemapRuleRow: View {
    @Environment(RemapViewModel.self) private var vm
    let rule: RemapRule
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in vm.toggleRule(rule) }))
                .toggleStyle(.switch).labelsHidden().scaleEffect(0.85)
            Button(action: onEdit) {
                HStack(spacing: 10) {
                    Chip(text: rule.input.displayName)
                    Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(.secondary)
                    Chip(text: rule.output.displayLabel)
                    if rule.smartDetect, rule.input.hasModifiers {
                        Chip(text: "⚡ Smart", size: .small)
                            .help("Fires only from a dedicated keyboard key. Typed \(rule.input.displayName) keeps its normal meaning.")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Edit this mapping")
            Spacer()
            Button(role: .destructive) { vm.removeRule(rule) } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
    }
}
