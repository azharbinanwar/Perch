//
//  MouseTabViewV4.swift
//  Perch
//
//  V4 layout — "if Apple built it": the same container/margins as the Clipboard tab
//  (ScrollView + GroupBox + SettingRow), with a native popup-button per action so setting
//  one is obvious. Same behaviour and view-model as the other versions.
//

import SwiftUI

struct MouseTabViewV4: View {
    @Environment(ScrollViewModel.self) private var scroll
    @Environment(MouseViewModel.self) private var mouse
    @Environment(PointerViewModel.self) private var pointer

    @State private var trusted = Permissions.isAccessibilityTrusted
    @State private var targetPrompt: MappingTargetV4?
    @State private var riskyTrigger: MouseTrigger?
    @State private var clickPick: ClickPickV4?
    @State private var gesturePick: GesturePickV4?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mouse").font(.title2.bold())
                if !trusted {
                    AccessibilityBanner(message: "Grant Accessibility so scroll, pointer, and buttons can work.")
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
            MouseActionPicker { kind in mouse.setGestureAction(MouseAction(kind: kind), direction: pick.direction, for: pick.gestureID) }
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
            Text("Left, Right, and Middle are your normal clicks. Perch never applies a mapping inside its own window.")
        }
    }

    // MARK: - Scroll / Pointer / Reliability

    private var scrollGroup: some View {
        GroupBox("Scroll") {
            VStack(spacing: 10) {
                SettingRow(title: "Reverse scroll direction",
                           subtitle: "Reverses external mouse scroll; the trackpad is left untouched.") {
                    toggle(scroll.isEnabled) { _ in scroll.toggle() }
                }
                Divider()
                SettingRow(title: "No acceleration (flat)",
                           subtitle: "Every notch scrolls the same amount, regardless of how fast you spin.") {
                    toggle(scroll.linear) { scroll.setLinear($0) }
                }
                Divider()
                SettingRow(title: "Scroll speed", subtitle: "Faster or slower than the system default.") {
                    slider(scroll.speed, in: 0.25...10, step: 0.25, format: "%.2f×") { scroll.setSpeed($0) }
                }
                comingSoon("Modifier + scroll = zoom")
                comingSoon("Auto-scroll (hold & move)")
            }
            .padding(6)
        }
    }

    private var pointerGroup: some View {
        GroupBox("Pointer") {
            VStack(spacing: 10) {
                SettingRow(title: "Control pointer acceleration",
                           subtitle: "Override macOS cursor acceleration — off leaves the system default.") {
                    toggle(pointer.override) { pointer.setOverride($0) }
                }
                if pointer.override {
                    Divider()
                    SettingRow(title: "Acceleration", subtitle: "0 = flat 1:1 tracking; higher = more.") {
                        slider(pointer.value, in: 0...20, step: 0.5, format: "%.1f") { pointer.setValue($0) }
                    }
                }
                comingSoon("Pointer speed")
            }
            .padding(6)
        }
    }

    private var reliabilityGroup: some View {
        GroupBox("Reliability") {
            VStack(spacing: 10) {
                SettingRow(title: "Ignore accidental double-clicks",
                           subtitle: "Fixes a worn switch that fires twice on one press.") {
                    toggle(mouse.debounce) { mouse.setDebounce($0) }
                }
                if mouse.debounce {
                    SettingRow(title: "Ignore window",
                               subtitle: "A second click within this time is dropped.") {
                        slider(mouse.debounceMs, in: 20...100, step: 5, format: "%.0f ms") { mouse.setDebounceMs($0) }
                    }
                }
                comingSoon("Swap primary / secondary")
            }
            .padding(6)
        }
    }

    // MARK: - Buttons

    private var buttonsGroup: some View {
        GroupBox("Buttons") {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Enable button mapping",
                           subtitle: "Assign buttons to shortcuts, actions, and gestures.") {
                    toggle(mouse.isEnabled) { mouse.setEnabled($0) }
                }
                Divider()
                detect
                VStack(alignment: .leading, spacing: 14) {
                    clickActions
                    gestures
                    comingSoon("Per-app profiles")
                }
                .opacity(mouse.isEnabled ? 1 : 0.4)
                .disabled(!mouse.isEnabled)
            }
            .padding(6)
        }
    }

    private var detect: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detect your extra buttons, and register any button that sends a keystroke.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(mouse.detectingButtons ? "Stop" : "Detect a button") { mouse.toggleButtonDetect() }
                Button("Add keystroke button") { mouse.startKeyCapture() }
                Spacer()
                if mouse.detectingButtons {
                    Text("Press a button").font(.system(size: 12)).foregroundStyle(.secondary)
                } else if !mouse.detectedButtons.isEmpty {
                    Button("Clear") { mouse.clearDetected() }.buttonStyle(.borderless)
                }
            }
            if !mouse.detectedButtons.isEmpty || !mouse.whitelist.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(mouse.detectedButtons, id: \.self) { chip($0.displayName, icon: triggerIcon($0), tint: .blue) }
                    ForEach(mouse.whitelist, id: \.self) { trigger in
                        HStack(spacing: 5) {
                            Label(trigger.displayName, systemImage: "keyboard").font(.system(size: 11, weight: .medium))
                            Button { mouse.removeWhitelisted(trigger) } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 10)) }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 4).background(.purple.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var clickActions: some View {
        Text("CLICK ACTIONS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
        SettingRow(title: "Left / Right", subtitle: "Your normal click") {
            Text("No change").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        ForEach(mouse.mappings) { mapping in
            Divider()
            groupHeader(icon: triggerIcon(mapping.trigger), title: mapping.trigger.displayName) { mouse.removeMapping(mapping.id) }
            ForEach(Array(phases(for: mapping).enumerated()), id: \.element) { index, phase in
                if index > 0 { subDivider }
                SettingRow(title: phase.title) {
                    actionControl(mapping.action(for: phase)) { clickPick = ClickPickV4(mappingID: mapping.id, phase: phase) }
                }
            }
        }
        ForEach(mouse.availableTriggers, id: \.self) { trigger in
            HStack {
                Label(trigger.displayName, systemImage: triggerIcon(trigger)).font(.system(size: 12))
                Spacer()
                Button("Add") { requestAdd(trigger) }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var gestures: some View {
        if !mouse.gestures.isEmpty || !mouse.availableGestureButtons.isEmpty {
            Text("GESTURES — HOLD & FLICK").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            ForEach(mouse.gestures) { gesture in
                Divider()
                groupHeader(icon: "computermouse.fill", title: MouseButton.name(for: gesture.button)) { mouse.removeGesture(gesture.id) }
                ForEach(Array(GestureDirection.allCases.enumerated()), id: \.element) { index, direction in
                    if index > 0 { subDivider }
                    SettingRow(title: direction.title) {
                        actionControl(gesture.action(for: direction)) { gesturePick = GesturePickV4(gestureID: gesture.id, direction: direction) }
                    }
                }
            }
            ForEach(mouse.availableGestureButtons, id: \.self) { button in
                HStack {
                    Label(MouseButton.name(for: button), systemImage: "hand.draw").font(.system(size: 12))
                    Spacer()
                    Button("Add gesture") { mouse.addGesture(for: button) }
                }
                .padding(.vertical, 2)
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
        .padding(24).frame(width: 360)
    }

    // MARK: - Bits

    // Current action + a pen icon; tapping opens our picker (not a native dropdown).
    private func actionControl(_ action: MouseAction, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text(action.displayLabel).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // A shorter, indented divider so sub-rows read as children of the button above.
    private var subDivider: some View {
        Divider().padding(.leading, 24)
    }

    private func groupHeader(icon: String, title: String, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(title).font(.system(size: 12, weight: .semibold))
            Spacer()
            Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.borderless)
        }
        .padding(.top, 4)
    }

    private func toggle(_ isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: action)).toggleStyle(.switch).labelsHidden()
    }

    private func slider(_ value: Double, in range: ClosedRange<Double>, step: Double, format: String,
                        action: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: action), in: range, step: step).frame(width: 140)
            Text(String(format: format, value)).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
        }
    }

    private func comingSoon(_ title: String) -> some View {
        SettingRow(title: title) {
            Text("Coming soon").font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 7).padding(.vertical, 2).background(.quaternary, in: Capsule()).foregroundStyle(.secondary)
        }
        .opacity(0.55)
    }

    private func chip(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon).font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9).padding(.vertical, 4).background(tint.opacity(0.15), in: Capsule())
    }

    private func phases(for mapping: MouseMapping) -> [ClickPhase] {
        if case .key = mapping.trigger { return [.single] }
        return ClickPhase.allCases
    }

    private func triggerIcon(_ trigger: MouseTrigger) -> String {
        if case .button(let n) = trigger { return MouseButton.icon(for: n) }
        return "keyboard"
    }

    private func requestAdd(_ trigger: MouseTrigger) {
        if case .button(2) = trigger { riskyTrigger = trigger } else { mouse.addMapping(for: trigger) }
    }

    private func pickClick(_ kind: MouseActionKind, phase: ClickPhase, for id: UUID) {
        if kind.target == .none {
            mouse.setAction(MouseAction(kind: kind), phase: phase, for: id)
        } else {
            targetPrompt = MappingTargetV4(mappingID: id, phase: phase, kind: kind)
        }
    }

    @ViewBuilder
    private func targetSheet(_ prompt: MappingTargetV4) -> some View {
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

private struct ClickPickV4: Identifiable { let id = UUID(); let mappingID: UUID; let phase: ClickPhase }
private struct GesturePickV4: Identifiable { let id = UUID(); let gestureID: UUID; let direction: GestureDirection }
private struct MappingTargetV4: Identifiable { let id = UUID(); let mappingID: UUID; let phase: ClickPhase; let kind: MouseActionKind }
