import SwiftUI

struct MouseShiftGroup: View {
    @Environment(MouseViewModel.self) private var mouse
    @State private var layerSel = "left"
    @State private var layerHoldPick: MouseTrigger?
    @State private var layerSlotPicking: LayerSlotPick?
    @State private var layerHoldWarning: LayerHoldWarning?
    @State private var layerDeleteConfirm = false
    @State private var layerIntroShowing = false
    @State private var targetPrompt: MappingTarget?

    private struct LayerSlotPick: Identifiable {
        let id: String
        let target: String
        let phase: ClickPhase
    }
    private struct LayerHoldWarning: Identifiable {
        let id = UUID()
        let holdLabel: String
        let pendingPick: LayerSlotPick
    }

    private static let layerNames: [String: String] = [
        "left": "Left click", "right": "Right click", "middle": "Middle", "top": "Top",
        "back": "Back (4)", "fwd": "Forward (5)", "rup": "Button 6", "rdn": "Button 7",
    ]

    private var profileLabel: String { mouse.isEditingDefault ? "All apps" : mouse.editingProfileName }

    private var layerHoldChoices: [MouseTrigger] {
        [.button(2)] + mouse.detectedButtons.filter { trigger in
            if case .button(let n) = trigger { return n >= 3 } else { return false }
        }
    }
    private var layerHoldSelected: MouseTrigger {
        layerHoldPick ?? mouse.editingLayer.layers.first?.hold ?? .button(2)
    }
    private var layerHoldName: String {
        layerHoldSelected == .button(2) ? "Middle" : layerHoldSelected.displayName
    }
    private var layerHoldIDs: Set<String> {
        Set([layerHoldSelected].compactMap(mouse.hotspotFor))
    }

    var body: some View {
        let layerOn = mouse.editingLayer.enabled
        let count = mouse.layerActionCount
        return SettingGroup("Mouse Shift — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Enable Mouse Shift",
                           subtitle: layerOn
                               ? "Hold a shift key, then press another button — it runs that combo's action. \(count) combo\(count == 1 ? "" : "s") set."
                               : "Hold one button to give every other button a second set of actions — like ⇧ for your mouse.",
                           icon: "command") {
                    HStack(spacing: 10) {
                        Button { layerIntroShowing = true } label: {
                            Image(systemName: "info.circle").font(.system(size: 16)).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("See how Mouse Shift works")
                        SwitchToggle(isOn: mouse.editingLayer.enabled) { on in mouse.updateLayer { $0.enabled = on } }
                    }
                }
                if layerOn {
                    Divider()
                    HStack(spacing: 6) {
                        Text("Hold button").font(.system(size: 12, weight: .medium))
                        Spacer()
                        ForEach(layerHoldChoices, id: \.self) { trigger in
                            let editing = layerHoldSelected == trigger
                            let combos = mouse.layerActionCount(hold: trigger)
                            let name = trigger == .button(2) ? "Middle" : trigger.displayName
                            Button {
                                layerHoldPick = trigger
                                if mouse.hotspotFor(trigger) == layerSel { layerSel = "left" }
                            } label: {
                                Text(editing ? "HOLD · \(name)" : (combos > 0 ? "\(name) · \(combos)" : name))
                                    .font(.system(size: 11, weight: editing ? .bold : .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(editing ? AnyShapeStyle(Color.secondaryAccent)
                                                : combos > 0 ? AnyShapeStyle(Color.secondaryAccent.opacity(0.15))
                                                             : AnyShapeStyle(Color.primary.opacity(0.06)),
                                                in: Capsule())
                                    .foregroundStyle(editing ? Color.white : (combos > 0 ? Color.secondaryAccent : Color.secondary))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if layerHoldChoices.count == 1 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").font(.system(size: 16)).foregroundStyle(.secondary)
                            Text("Only Middle can power the layer right now — scan your mouse's extra buttons to unlock more.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            if mouse.scanning {
                                HStack(spacing: 6) {
                                    Circle().fill(.green).frame(width: 6, height: 6)
                                    Text("Press your buttons…").font(.system(size: 11, weight: .medium))
                                }
                            } else {
                                Button("Scan buttons") { mouse.startScan() }.font(.system(size: 11))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                    holdConflictTile
                    Divider()
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 8) {
                            MouseDiagramView(selected: $layerSel,
                                             isMapped: { id in
                                                 guard let t = mouse.triggerFor(id) else { return false }
                                                 return ClickPhase.allCases.contains { mouse.layerAction(hold: layerHoldSelected, for: t, phase: $0).kind != .disabled }
                                             },
                                             isActive: mouse.isActiveHotspot,
                                             holdIDs: layerHoldIDs,
                                             onSelect: { layerSel = $0 })
                                .padding(.leading, 4)
                            Text("Hold the amber button, then click any other\nbutton here to set its second action.")
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Hold").font(.system(size: 12)).foregroundStyle(.secondary)
                                Text(layerHoldName).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondaryAccent)
                                Text(", then").font(.system(size: 12)).foregroundStyle(.secondary)
                                Text(layerName(layerSel).lowercased()).font(.system(size: 12, weight: .semibold))
                                Spacer()
                                if mouse.layerActionCount(hold: layerHoldSelected) > 0 {
                                    Button { layerDeleteConfirm = true } label: {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete all of \(layerHoldName)'s combos")
                                    .alert("Delete \(layerHoldName)'s combos?", isPresented: $layerDeleteConfirm) {
                                        Button("Cancel", role: .cancel) {}
                                        Button("Delete", role: .destructive) { mouse.removeLayer(hold: layerHoldSelected) }
                                    } message: {
                                        Text("All \(mouse.layerActionCount(hold: layerHoldSelected)) combo\(mouse.layerActionCount(hold: layerHoldSelected) == 1 ? "" : "s") under \(layerHoldName) are removed. Other shift keys keep theirs.")
                                    }
                                }
                            }
                            .padding(.bottom, 6)
                            Divider()
                            ForEach(ClickPhase.allCases) { phase in
                                layerSlotRow(target: layerSel, phase: phase)
                            }
                            Spacer(minLength: 8)
                            Text("Left and right click are safe to set here — the layer only applies while \(layerHoldName) is held down.")
                                .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .opacity(mouse.isEnabled ? 1 : 0.5)
        .disabled(!mouse.isEnabled)
        .alert(item: $layerHoldWarning) { layerHoldAlert($0) }
        .sheet(isPresented: $layerIntroShowing) { MouseShiftIntroSheet() }
        .sheet(item: $layerSlotPicking) { pick in
            ActionPicker(excluding: [.passThrough]) { kind in
                guard let trigger = mouse.triggerFor(pick.target) else { return }
                if kind.target == .none {
                    mouse.setLayerAction(Action(kind: kind), hold: layerHoldSelected, for: trigger, phase: pick.phase)
                } else {
                    targetPrompt = MappingTarget(trigger: trigger, phase: pick.phase, kind: kind, layerHold: layerHoldSelected)
                }
            }
        }
        .sheet(item: $targetPrompt) { MouseTargetSheet(prompt: $0) }
    }

    private func layerName(_ id: String) -> String { Self.layerNames[id] ?? id }

    private func holdConflict(for trigger: MouseTrigger) -> String? {
        let action = mouse.action(for: trigger, phase: .hold)
        return action.kind == .disabled ? nil : action.displayLabel
    }

    @ViewBuilder
    private var holdConflictTile: some View {
        if let conflict = holdConflict(for: layerHoldSelected) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryAccent)
                    .frame(width: 26, height: 26)
                    .background(Color.secondaryAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(layerHoldName).font(.system(size: 13, weight: .semibold))
                        Text("HOLD IN USE")
                            .font(.system(size: 9, weight: .bold)).kerning(0.5)
                            .foregroundStyle(Color.secondaryAccent)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.secondaryAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text("Its Hold action — \(conflict) — will be removed when you set its first shift combo. Click and double-click keep working.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.secondaryAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func layerHoldAlert(_ warning: LayerHoldWarning) -> Alert {
        Alert(
            title: Text("Remove \(layerHoldName)'s Hold action?"),
            message: Text("\(layerHoldName) uses Hold for “\(warning.holdLabel)”. Holding becomes the shift gesture, so that action is removed first — then pick your shift action. Click and double-click keep working."),
            primaryButton: .destructive(Text("Remove & Continue")) {
                mouse.setAction(.disabled, for: layerHoldSelected, phase: .hold)
                let pick = warning.pendingPick
                DispatchQueue.main.async { layerSlotPicking = pick }
            },
            secondaryButton: .cancel()
        )
    }

    private func layerPhaseLabel(_ phase: ClickPhase) -> String {
        switch phase {
        case .single: return "Click"
        case .double: return "Double click"
        case .hold:   return "Hold"
        }
    }

    private func layerSlotRow(target: String, phase: ClickPhase) -> some View {
        let action = mouse.triggerFor(target).map { mouse.layerAction(hold: layerHoldSelected, for: $0, phase: phase) } ?? .disabled
        return SettingRow(title: layerPhaseLabel(phase),
                          value: action.kind == .disabled ? "" : action.displayLabel,
                          compact: true) {
            let pick = LayerSlotPick(id: "\(target)|\(phase.rawValue)", target: target, phase: phase)
            if let conflict = holdConflict(for: layerHoldSelected) {
                layerHoldWarning = LayerHoldWarning(holdLabel: conflict, pendingPick: pick)
            } else {
                layerSlotPicking = pick
            }
        }
    }
}
