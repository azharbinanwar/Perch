//
//  MouseTabView.swift
//  Perch
//
//  The Mouse page: Scroll · Pointer · Your mouse buttons (detect + whitelist) · Set actions
//  & gestures. Keyboard remapping stays on the Keys tab.
//

import SwiftUI

struct MouseTabView: View {
    @Environment(ScrollViewModel.self) private var scroll
    @Environment(MouseViewModel.self) private var mouse
    @Environment(PointerViewModel.self) private var pointer

    @State private var trusted = Permissions.isAccessibilityTrusted
    @State private var clickPick: ClickPick?
    @State private var gesturePick: GesturePick?
    @State private var targetPrompt: MappingTarget?
    @State private var riskyTrigger: MouseTrigger?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mouse").font(.title2.bold())
                if !trusted {
                    AccessibilityBanner(message: "Grant Accessibility so scroll, pointer, and button features can work.")
                }
                scrollGroup
                pointerGroup
                buttonsGroup
                reliabilityGroup
            }
            .padding(20)
        }
        .onAppear { trusted = Permissions.isAccessibilityTrusted }
        .onDisappear { mouse.stopButtonDetect(); mouse.cancelKeyCapture() }
        .sheet(item: $clickPick) { pick in
            MouseActionPicker { kind in pickClick(kind, phase: pick.phase, for: pick.mappingID) }
        }
        .sheet(item: $gesturePick) { pick in
            MouseActionPicker { kind in
                mouse.setGestureAction(MouseAction(kind: kind), direction: pick.direction, for: pick.gestureID)
            }
        }
        .sheet(item: $targetPrompt) { targetSheet($0) }
        .sheet(isPresented: Binding(get: { mouse.capturingKey }, set: { if !$0 { mouse.cancelKeyCapture() } })) {
            keyCaptureSheet
        }
        .alert("Map \(riskyTrigger?.displayName ?? "")?",
               isPresented: Binding(get: { riskyTrigger != nil }, set: { if !$0 { riskyTrigger = nil } })) {
            Button("Add Anyway") { if let t = riskyTrigger { mouse.addMapping(for: t) }; riskyTrigger = nil }
            Button("Cancel", role: .cancel) { riskyTrigger = nil }
        } message: {
            Text("Left, Right, and Middle are your normal clicks. Perch never applies a mapping inside its own window, so you can always change or delete it here.")
        }
    }

    // MARK: - Scroll

    private var scrollGroup: some View {
        GroupBox("Scroll") {
            VStack(spacing: 10) {
                SettingRow(title: "Reverse scroll direction",
                           subtitle: "Reverses external mouse scroll; the trackpad is left untouched.") {
                    Toggle("", isOn: Binding(get: { scroll.isEnabled }, set: { _ in scroll.toggle() }))
                        .toggleStyle(.switch).labelsHidden()
                }
                Divider()
                SettingRow(title: "No acceleration (flat)",
                           subtitle: "Every notch scrolls the same amount, regardless of how fast you spin.") {
                    Toggle("", isOn: Binding(get: { scroll.linear }, set: { scroll.setLinear($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
                Divider()
                SettingRow(title: "Scroll speed", subtitle: "Faster or slower than the system default.") {
                    HStack(spacing: 8) {
                        Slider(value: Binding(get: { scroll.speed }, set: { scroll.setSpeed($0) }), in: 0.25...10, step: 0.25)
                            .frame(width: 140)
                        Text(String(format: "%.2f×", scroll.speed))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                comingSoon("plus.magnifyingglass", "Modifier + scroll = zoom")
                comingSoon("arrow.up.and.down.and.arrow.left.and.right", "Auto-scroll (hold & move)")
            }
            .padding(6)
        }
    }

    /// A subtle placeholder row for features that aren't built yet.
    private func comingSoon(_ icon: String, _ title: String) -> some View {
        TileRow(icon: icon, title: title) {
            Text("Coming soon")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.secondary)
        }
        .opacity(0.55)
    }

    // MARK: - Pointer

    private var pointerGroup: some View {
        GroupBox("Pointer") {
            VStack(spacing: 10) {
                SettingRow(title: "Control pointer acceleration",
                           subtitle: "Override macOS cursor acceleration — off leaves the system default.") {
                    Toggle("", isOn: Binding(get: { pointer.override }, set: { pointer.setOverride($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
                if pointer.override {
                    Divider()
                    SettingRow(title: "Acceleration", subtitle: "0 = flat 1:1 tracking (no acceleration); higher = more.") {
                        HStack(spacing: 8) {
                            Slider(value: Binding(get: { pointer.value }, set: { pointer.setValue($0) }), in: 0...20, step: 0.5)
                                .frame(width: 140)
                            Text(pointer.value <= 0 ? "Off" : String(format: "%.1f", pointer.value))
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
                comingSoon("cursorarrow.motionlines", "Pointer speed")
            }
            .padding(6)
        }
    }

    // MARK: - Buttons (detect + whitelist + actions + gestures)

    private var buttonsGroup: some View {
        GroupBox("Buttons") {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Enable button mapping",
                           subtitle: "Assign your buttons to shortcuts, actions, and gestures.") {
                    Toggle("", isOn: Binding(get: { mouse.isEnabled }, set: { mouse.setEnabled($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
                Divider()
                detectRow
                VStack(alignment: .leading, spacing: 12) {
                    actionsList
                    gesturesList
                    comingSoon("rectangle.on.rectangle.angled", "Per-app profiles")
                }
                .opacity(mouse.isEnabled ? 1 : 0.4)
                .disabled(!mouse.isEnabled)
            }
            .padding(6)
        }
    }

    private var reliabilityGroup: some View {
        GroupBox("Reliability") {
            VStack(alignment: .leading, spacing: 10) {
                debounceRows
                comingSoon("arrow.left.arrow.right", "Swap primary / secondary")
            }
            .padding(6)
        }
    }

    private var detectRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detect your extra buttons, and register any button that sends a keystroke.")
                .font(.system(size: 12)).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button(mouse.detectingButtons ? "Stop" : "Detect a button") { mouse.toggleButtonDetect() }
                    Button("Add keystroke button") { mouse.startKeyCapture() }
                    Spacer()
                    if mouse.detectingButtons {
                        HStack(spacing: 5) {
                            Circle().fill(.green).frame(width: 7, height: 7)
                            Text("Press a button").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    } else if !mouse.detectedButtons.isEmpty {
                        Button("Clear") { mouse.clearDetected() }.buttonStyle(.borderless)
                    }
                }

                if mouse.detectedButtons.isEmpty && mouse.whitelist.isEmpty {
                    Text("Nothing detected yet.").font(.system(size: 11)).foregroundStyle(.tertiary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(mouse.detectedButtons, id: \.self) { trigger in
                            chip(trigger.displayName, icon: triggerIcon(trigger), tint: .blue)
                        }
                        ForEach(mouse.whitelist, id: \.self) { trigger in
                            HStack(spacing: 5) {
                                Label(trigger.displayName, systemImage: "keyboard").font(.system(size: 11, weight: .medium))
                                Button { mouse.removeWhitelisted(trigger) } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                                }.buttonStyle(.plain).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.purple.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private func chip(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
    }

    // MARK: - Actions & gestures lists (used inside the Buttons group)

    @ViewBuilder
    private var actionsList: some View {
        Text("Click actions").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        VStack(spacing: 12) {
            TileRow(icon: "computermouse", title: "Left / Right") {
                Text("Normal click — no change").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            ForEach(mouse.mappings) { mapping in
                MouseMappingCard(mapping: mapping,
                                 onPick: { clickPick = ClickPick(mappingID: mapping.id, phase: $0) },
                                 onDelete: { mouse.removeMapping(mapping.id) })
            }
            ForEach(mouse.availableTriggers, id: \.self) { trigger in
                Button { requestAdd(trigger) } label: {
                    TileRow(icon: triggerIcon(trigger), title: trigger.displayName) {
                        HStack(spacing: 6) {
                            Text("Set action").font(.system(size: 11)).foregroundStyle(.tertiary)
                            Image(systemName: "plus.circle").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var gesturesList: some View {
        if !mouse.gestures.isEmpty || !mouse.availableGestureButtons.isEmpty {
            Text("Gestures — hold & flick").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            VStack(spacing: 12) {
                ForEach(mouse.gestures) { gesture in
                    MouseGestureCard(gesture: gesture,
                                     onPick: { gesturePick = GesturePick(gestureID: gesture.id, direction: $0) },
                                     onDelete: { mouse.removeGesture(gesture.id) })
                }
                ForEach(mouse.availableGestureButtons, id: \.self) { button in
                    Button { mouse.addGesture(for: button) } label: {
                        TileRow(icon: "hand.draw", title: MouseButton.name(for: button)) {
                            HStack(spacing: 6) {
                                Text("Add gesture").font(.system(size: 11)).foregroundStyle(.tertiary)
                                Image(systemName: "plus.circle").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var debounceRows: some View {
        SettingRow(title: "Ignore accidental double-clicks",
                   subtitle: "Fixes a worn switch that fires twice on one press.") {
            Toggle("", isOn: Binding(get: { mouse.debounce }, set: { mouse.setDebounce($0) }))
                .toggleStyle(.switch).labelsHidden()
        }
        if mouse.debounce {
            SettingRow(title: "Ignore window",
                       subtitle: "A second click within this time is dropped. Keep it below your double-click speed.") {
                HStack(spacing: 8) {
                    Slider(value: Binding(get: { mouse.debounceMs }, set: { mouse.setDebounceMs($0) }), in: 20...100, step: 5)
                        .frame(width: 140)
                    Text("\(Int(mouse.debounceMs)) ms")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }

    private var keyCaptureSheet: some View {
        VStack(spacing: 14) {
            Image(systemName: "keyboard").font(.system(size: 28)).foregroundStyle(.secondary)
            Text("Press your mouse's keystroke button now").font(.headline)
            Text("The next key press is registered as a button. Normal typing is ignored otherwise.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Cancel") { mouse.cancelKeyCapture() }.keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 360)
    }

    // MARK: - Helpers

    private func triggerIcon(_ trigger: MouseTrigger) -> String {
        switch trigger {
        case .button(let n): return MouseButton.icon(for: n)
        case .key:           return "keyboard"
        }
    }

    private func requestAdd(_ trigger: MouseTrigger) {
        if case .button(2) = trigger { riskyTrigger = trigger }
        else { mouse.addMapping(for: trigger) }
    }

    private func pickClick(_ kind: MouseActionKind, phase: ClickPhase, for id: UUID) {
        if kind.target == .none {
            mouse.setAction(MouseAction(kind: kind), phase: phase, for: id)
        } else {
            targetPrompt = MappingTarget(mappingID: id, phase: phase, kind: kind)
        }
    }

    @ViewBuilder
    private func targetSheet(_ prompt: MappingTarget) -> some View {
        switch prompt.kind.target {
        case .app:
            AppPickerSheet { ids in
                if let bundle = ids.first {
                    mouse.setAction(MouseAction(kind: .openApp, target: bundle), phase: prompt.phase, for: prompt.mappingID)
                }
            }
        case .keystroke:
            KeystrokeCaptureSheet { code, mods in
                mouse.setAction(MouseAction(kind: .customKeystroke, keyCode: Int(code), modifiers: mods), phase: prompt.phase, for: prompt.mappingID)
            }
        case .url, .file:
            TextTargetSheet(isFile: prompt.kind.target == .file) { text in
                let kind: MouseActionKind = prompt.kind.target == .file ? .openFile : .openURL
                mouse.setAction(MouseAction(kind: kind, target: text), phase: prompt.phase, for: prompt.mappingID)
            }
        default:
            EmptyView()
        }
    }
}

private struct ClickPick: Identifiable {
    let id = UUID()
    let mappingID: UUID
    let phase: ClickPhase
}

private struct MappingTarget: Identifiable {
    let id = UUID()
    let mappingID: UUID
    let phase: ClickPhase
    let kind: MouseActionKind
}

private struct GesturePick: Identifiable {
    let id = UUID()
    let gestureID: UUID
    let direction: GestureDirection
}
