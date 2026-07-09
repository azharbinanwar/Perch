import SwiftUI

struct ButtonsGroup: View {
    @Environment(MouseViewModel.self) private var mouse
    @State private var selDiagram = "middle"
    @State private var clickPick: ClickPick?
    @State private var gesturePick: GesturePick?
    @State private var targetPrompt: MappingTarget?
    @State private var autoScrollHoldWarn: ClickPick?   // tapped Auto-scroll's Middle·Hold
    @State private var shiftHoldClear: ClickPick?       // tapped a Mouse-Shift Hold to reclaim it

    private var profileLabel: String { mouse.isEditingDefault ? "All apps" : mouse.editingProfileName }

    var body: some View {
        SettingGroup("Buttons — \(profileLabel)") {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Enable button mapping",
                           subtitle: "Assign buttons to shortcuts, actions, and gestures.",
                           icon: "cursorarrow.click") {
                    SwitchToggle(isOn: mouse.isEnabled) { mouse.setEnabled($0) }
                }
                Divider()
                detect
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 8) {
                            MouseDiagramView(selected: $selDiagram, isMapped: mouse.isMappedHotspot,
                                             isActive: mouse.isActiveHotspot, onSelect: { selDiagram = $0 })
                                .padding(.leading, 4)
                                .onChange(of: mouse.addCount) { _, _ in
                                    if let t = mouse.lastAdded, let id = mouse.hotspotFor(t) { selDiagram = id }
                                }
                            Text("Click a button").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        Divider()
                        detailPanel.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(mouse.isEnabled ? 1 : 0.4)
                .disabled(!mouse.isEnabled)
            }
        }
        .sheet(item: $clickPick) { pick in
            ActionPicker { kind in pickClick(kind, trigger: pick.trigger, phase: pick.phase) }
        }
        .sheet(item: $gesturePick) { pick in
            ActionPicker { kind in mouse.setGestureAction(Action(kind: kind), for: pick.button, direction: pick.direction) }
        }
        .sheet(item: $targetPrompt) { MouseTargetSheet(prompt: $0) }
        .alert("Change Middle · Hold?", isPresented: Binding(
            get: { autoScrollHoldWarn != nil },
            set: { if !$0 { autoScrollHoldWarn = nil } })) {
            Button("Cancel", role: .cancel) { autoScrollHoldWarn = nil }
            Button("Turn Off") {   // reversible → not destructive
                if let pick = autoScrollHoldWarn {
                    mouse.updateScroll { $0.autoOn = false }
                    clickPick = pick
                }
                autoScrollHoldWarn = nil
            }
        } message: {
            Text("Hold powers Auto-scroll. Setting an action here turns Auto-scroll off. Click and double-click keep working.")
        }
        // Mouse Shift: reclaiming the button clears that shift key's combos — same action & wording
        // as the delete-combos confirm in the Mouse Shift section (unify styling later).
        .alert("Delete \(shiftHoldName)'s combos?", isPresented: Binding(
            get: { shiftHoldClear != nil },
            set: { if !$0 { shiftHoldClear = nil } })) {
            Button("Cancel", role: .cancel) { shiftHoldClear = nil }
            Button("Delete", role: .destructive) {
                if let pick = shiftHoldClear {
                    mouse.removeLayer(hold: pick.trigger)   // frees just this shift key; others keep theirs
                    clickPick = pick
                }
                shiftHoldClear = nil
            }
        } message: {
            Text(shiftHoldClearMessage)
        }
    }

    private var shiftHoldName: String {
        guard let t = shiftHoldClear?.trigger else { return "this button" }
        return mouse.hotspotMeta(mouse.hotspotFor(t) ?? "").name
    }

    private var shiftHoldClearMessage: String {
        guard let t = shiftHoldClear?.trigger else { return "" }
        let n = mouse.layerActionCount(hold: t)
        return "All \(n) combo\(n == 1 ? "" : "s") under \(shiftHoldName) are removed. Other shift keys keep theirs."
    }

    // A Hold slot claimed by another feature (Mouse Shift / Auto-scroll): the owner is named in an
    // amber lock subtitle, and any stored action stays visible but struck-through (kept, just inert).
    // Tapping runs `onTap` to reclaim the slot (turn auto-scroll off / clear the shift key).
    private func lockedHoldRow(_ trigger: MouseTrigger, owner: String, onTap: (() -> Void)? = nil) -> some View {
        let action = mouse.action(for: trigger, phase: .hold)
        return ActionSlotRow(title: "Hold", onTap: onTap) {
            Text("Used by \(owner)").font(.system(size: 11)).foregroundStyle(Color.warning)
        } trailing: {
            HStack(spacing: 8) {
                if action.kind != .disabled {
                    Text(action.displayLabel)
                        .font(.system(size: 12)).foregroundStyle(.tertiary)
                        .strikethrough(true, color: .secondary)
                        .lineLimit(1).truncationMode(.tail)
                }
                Image(systemName: "lock.fill")
                    .font(.system(size: 10)).foregroundStyle(Color.warning)
            }
        }
    }

    @ViewBuilder
    private var detect: some View {
        if mouse.scanning {
            HStack(spacing: 10) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("Scanning — press each button on your mouse. Don't touch the keyboard.")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button("Done") { mouse.stopScan() }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else {
            HStack(spacing: 10) {
                Button { mouse.startScan() } label: { Label("Scan buttons", systemImage: "dot.viewfinder") }
                Text("Press your mouse's extra buttons to add them — even ones that type a shortcut.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        let meta = mouse.hotspotMeta(selDiagram)
        VStack(alignment: .leading, spacing: 12) {
            panelHeader(meta)
            if meta.locked {
                Text("\(meta.name) is your normal click and can't be remapped. Pick another button on the mouse.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else if let trigger = mouse.triggerFor(selDiagram) {
                let isShiftKey = mouse.isShiftHold(trigger)
                block("CLICK") {
                    let phases = mouse.phases(forTrigger: trigger)
                    ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                        if index > 0 { Divider() }
                        if isShiftKey && phase == .hold {
                            // Restricted BY a shift key → tap to reclaim it (clears that key's combos).
                            lockedHoldRow(trigger, owner: "Mouse Shift") {
                                shiftHoldClear = ClickPick(trigger: trigger, phase: .hold)
                            }
                        } else if mouse.isAutoScrollHold(trigger) && phase == .hold {
                            // Owned by auto-scroll → tap to reclaim it (turns auto-scroll off).
                            lockedHoldRow(trigger, owner: "Auto-scroll") {
                                autoScrollHoldWarn = ClickPick(trigger: trigger, phase: .hold)
                            }
                        } else {
                            panelRow(phase.title, action: mouse.action(for: trigger, phase: phase),
                                     fallback: mouse.predefinedLabel(trigger, phase)) {
                                clickPick = ClickPick(trigger: trigger, phase: phase)
                            }
                        }
                    }
                }
                if meta.gestures {
                    block("GESTURE · HOLD & FLICK") {
                        ForEach(Array(GestureDirection.allCases.enumerated()), id: \.element) { index, direction in
                            if index > 0 { Divider() }
                            panelRow(direction.title, action: mouse.gestureAction(for: 2, direction: direction)) {
                                gesturePick = GesturePick(button: 2, direction: direction)
                            }
                        }
                    }
                }
            }
        }
    }

    private func panelHeader(_ meta: MouseHotspotMeta) -> some View {
        HStack(spacing: 9) {
            Image(systemName: meta.icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26).background(Color.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(meta.name).font(.system(size: 13, weight: .semibold))
                Text(meta.sub).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if let t = mouse.triggerFor(selDiagram) {
                if case .key = t {
                    Button { mouse.removeWhitelisted(t); selDiagram = "middle" } label: {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless).help("Remove this keystroke button")
                } else if let m = mouse.mapping(for: t) {
                    Button { mouse.removeMapping(m.id) } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless).help("Reset this button")
                }
            }
        }
    }

    private func block<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.4)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
            content()
        }
    }

    private func panelRow(_ title: String, action: Action, fallback: String? = nil,
                          onTap: @escaping () -> Void) -> some View {
        let off = action.kind == .disabled
        return ActionSlotRow(title: title, value: off ? (fallback ?? "") : action.displayLabel, onTap: onTap)
    }

    private func pickClick(_ kind: ActionKind, trigger: MouseTrigger, phase: ClickPhase) {
        if kind.target == .none {
            mouse.setAction(Action(kind: kind), for: trigger, phase: phase)
        } else {
            targetPrompt = MappingTarget(trigger: trigger, phase: phase, kind: kind)
        }
    }
}

private struct ClickPick: Identifiable { let id = UUID(); let trigger: MouseTrigger; let phase: ClickPhase }
private struct GesturePick: Identifiable { let id = UUID(); let button: Int; let direction: GestureDirection }
