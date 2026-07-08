//
//  DoubleTapGroup.swift
//  Perch
//
//  The Double-Tap section of the Keys tab — a standalone component, used directly in RemapTabView's
//  body. Owns its action-picker and info sheets.
//

import SwiftUI

struct DoubleTapGroup: View {
    @Environment(RemapViewModel.self) private var vm
    @State private var introShowing = false
    @State private var picking: ModPick?

    private struct ModPick: Identifiable { let id: String }
    private var moduleActive: Bool { AccessibilityService.shared.isTrusted && vm.isEnabled }
    private var profileLabel: String { vm.isEditingDefault ? "All apps" : vm.editingProfileName }

    /// Double-tap picks fire immediately — no target prompt flow — so exclude kinds needing one.
    private var excluded: Set<ActionKind> {
        Set(ActionKind.allCases.filter { $0.target != .none }).union([.passThrough])
    }

    var body: some View {
        SettingGroup("Double-Tap — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Enable double-tap",
                           subtitle: "Tap a modifier twice quickly to run an action — normal shortcuts are never affected.",
                           icon: "hand.tap") {
                    HStack(spacing: 10) {
                        Button { introShowing = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16)).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless).help("See how Double-Tap works")
                        Toggle("", isOn: Binding(get: { vm.doubleTap.enabled }, set: { vm.setDoubleTapEnabled($0) }))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }
                if vm.doubleTap.enabled {
                    ForEach(DoubleTapManager.modifiers, id: \.key) { mod in
                        Divider()
                        SettingRow(title: "Double-tap \(mod.symbol) \(mod.name)", icon: mod.key,
                                   value: vm.doubleTap.actions[mod.key]?.displayLabel ?? "",
                                   onTap: { picking = ModPick(id: mod.key) })
                    }
                }
            }
        }
        .opacity(moduleActive ? 1 : 0.5)
        .disabled(!moduleActive)
        .sheet(item: $picking) { pick in
            ActionPicker(excluding: excluded) { kind in
                vm.setDoubleTapAction(kind == .disabled ? nil : Action(kind: kind), for: pick.id)
            }
        }
        .sheet(isPresented: $introShowing) { DoubleTapIntroSheet() }
    }
}
