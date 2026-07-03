//
//  MouseTabViewV5.swift
//  Perch
//
//  V5 — one card per button. Everything a single button does (its Click / Double / Hold
//  variants AND its hold-&-flick gesture) lives in one self-contained card, so a button and
//  its actions never read as scattered. Same view-model, same picker sheet as V4.
//

import SwiftUI

struct MouseTabViewV5: View {
    @Environment(ScrollViewModel.self) private var scroll
    @Environment(MouseViewModel.self) private var mouse
    @Environment(PointerViewModel.self) private var pointer

    @State private var trusted = Permissions.isAccessibilityTrusted
    @State private var clickPick: ClickPickV5?
    @State private var gesturePick: GesturePickV5?
    @State private var targetPrompt: MappingTargetV5?
    @State private var riskyTrigger: MouseTrigger?
    @State private var addingProfile = false

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
        .sheet(isPresented: $addingProfile) {
            AppPickerSheet { ids in if let id = ids.first { mouse.addProfile(bundleID: id) } }
        }
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
                Divider()
                SettingRow(title: "Auto-scroll",
                           subtitle: "Long-press the middle button, then move to scroll. Release to keep scrolling; any click stops.") {
                    toggle(scroll.autoScroll) { scroll.setAutoScroll($0) }
                }
                if scroll.autoScroll {
                    SettingRow(title: "Sensitivity") {
                        slider(scroll.autoScrollSpeed, in: 0.1...4, step: 0.05, format: "%.2f×") { scroll.setAutoScrollSpeed($0) }
                    }
                }
                comingSoon("Modifier + scroll = zoom")
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
                    SettingRow(title: "Ignore window", subtitle: "A second click within this time is dropped.") {
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
                VStack(alignment: .leading, spacing: 12) {
                    profileSwitcher
                    Divider()
                    SettingRow(title: "Left / Right", subtitle: "Your normal click") {
                        Text("No change").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    ForEach(mouse.mappings) { buttonCard($0) }
                    ForEach(orphanGestures) { gestureOnlyCard($0) }
                    ForEach(mouse.availableTriggers, id: \.self) { addRow($0) }
                }
                .opacity(mouse.isEnabled ? 1 : 0.4)
                .disabled(!mouse.isEnabled)
            }
            .padding(6)
        }
    }

    // A full button: header + its click variants + (for physical buttons) its gesture.
    private func buttonCard(_ mapping: MouseMapping) -> some View {
        let button = buttonNumber(mapping.trigger)
        let gesture = button.flatMap { n in mouse.gestures.first { $0.button == n } }
        return VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: triggerIcon(mapping.trigger), title: mapping.trigger.displayName, tint: .blue) {
                mouse.removeMapping(mapping.id)
            }

            block("CLICK") {
                let phases = phases(for: mapping)
                ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                    if index > 0 { subDivider }
                    actionRow(title: phase.title, icon: phase.icon, action: mapping.action(for: phase)) {
                        clickPick = ClickPickV5(mappingID: mapping.id, phase: phase)
                    }
                }
            }

            if let n = button, n >= 2 {
                if let gesture {
                    block("GESTURE · HOLD & FLICK", onRemove: { mouse.removeGesture(gesture.id) }) {
                        ForEach(Array(GestureDirection.allCases.enumerated()), id: \.element) { index, direction in
                            if index > 0 { subDivider }
                            actionRow(title: direction.title, icon: direction.icon, action: gesture.action(for: direction)) {
                                gesturePick = GesturePickV5(gestureID: gesture.id, direction: direction)
                            }
                        }
                    }
                } else {
                    Button { mouse.addGesture(for: n) } label: {
                        Label("Add hold-&-flick gesture", systemImage: "hand.draw").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(.tint)
                }
            }
        }
        .padding(12)
        .cardBackground()
    }

    // A gesture whose button has no click mapping yet — still one tidy card.
    private func gestureOnlyCard(_ gesture: MouseGesture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "computermouse.fill", title: MouseButton.name(for: gesture.button), tint: .indigo) {
                mouse.removeGesture(gesture.id)
            }
            block("GESTURE · HOLD & FLICK") {
                ForEach(Array(GestureDirection.allCases.enumerated()), id: \.element) { index, direction in
                    if index > 0 { subDivider }
                    actionRow(title: direction.title, icon: direction.icon, action: gesture.action(for: direction)) {
                        gesturePick = GesturePickV5(gestureID: gesture.id, direction: direction)
                    }
                }
            }
            Button { mouse.addMapping(for: .button(gesture.button)) } label: {
                Label("Add click actions", systemImage: "cursorarrow.click").font(.system(size: 12))
            }
            .buttonStyle(.plain).foregroundStyle(.tint)
        }
        .padding(12)
        .cardBackground()
    }

    private func addRow(_ trigger: MouseTrigger) -> some View {
        HStack(spacing: 8) {
            Image(systemName: triggerIcon(trigger)).frame(width: 20).foregroundStyle(.secondary)
            Text(trigger.displayName).font(.system(size: 12))
            Spacer()
            Button("Set up") { requestAdd(trigger) }
        }
        .padding(.vertical, 4)
    }

    // Which app's mappings you're editing. Default applies to every app without its own profile.
    private var profileSwitcher: some View {
        SettingRow(title: "Profile",
                   subtitle: mouse.isEditingDefault
                       ? "Applies to every app without its own profile."
                       : "Only active while \(mouse.editingProfileName) is frontmost.") {
            Menu(mouse.editingProfileName) {
                Button("Default") { mouse.selectProfile(nil) }
                if !mouse.appProfiles.isEmpty { Divider() }
                ForEach(mouse.appProfiles) { profile in
                    Button(profile.displayName) { mouse.selectProfile(profile.appBundleID) }
                }
                Divider()
                Button("Add app…") { addingProfile = true }
                if !mouse.isEditingDefault {
                    Button("Remove \(mouse.editingProfileName)", role: .destructive) { mouse.removeEditingProfile() }
                }
            }
            .frame(width: 150)
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

    // MARK: - Card pieces

    private func cardHeader(icon: String, title: String, tint: Color, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 26, height: 26).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary) }
                .buttonStyle(.borderless)
        }
    }

    private func block<Content: View>(_ label: String, onRemove: (() -> Void)? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.4)
                Spacer()
                if let onRemove {
                    Button(action: onRemove) { Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.tertiary) }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.bottom, 4)
            content()
        }
    }

    // Left: what triggers it. Right: current action + a pencil that opens our picker.
    private func actionRow(title: String, icon: String, action: MouseAction, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                Text(title).font(.system(size: 12))
                Spacer(minLength: 8)
                Text(action.displayLabel).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subDivider: some View { Divider().padding(.leading, 24) }

    private func toggle(_ isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle("", isOn: Binding(get: { isOn }, set: action)).toggleStyle(.switch).labelsHidden()
    }

    // Continuous slider (no `step`) so macOS doesn't draw tick dots; we snap to the step ourselves.
    private func slider(_ value: Double, in range: ClosedRange<Double>, step: Double, format: String,
                        action: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: { action(($0 / step).rounded() * step) }), in: range)
                .frame(width: 140)
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

    // MARK: - Data helpers

    private var orphanGestures: [MouseGesture] {
        let mapped = Set(mouse.mappings.compactMap { buttonNumber($0.trigger) })
        return mouse.gestures.filter { !mapped.contains($0.button) }
    }

    private func buttonNumber(_ trigger: MouseTrigger) -> Int? {
        if case .button(let n) = trigger { return n }
        return nil
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
            targetPrompt = MappingTargetV5(mappingID: id, phase: phase, kind: kind)
        }
    }

    @ViewBuilder
    private func targetSheet(_ prompt: MappingTargetV5) -> some View {
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

private extension View {
    func cardBackground() -> some View {
        background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary.opacity(0.5)))
    }
}

private struct ClickPickV5: Identifiable { let id = UUID(); let mappingID: UUID; let phase: ClickPhase }
private struct GesturePickV5: Identifiable { let id = UUID(); let gestureID: UUID; let direction: GestureDirection }
private struct MappingTargetV5: Identifiable { let id = UUID(); let mappingID: UUID; let phase: ClickPhase; let kind: MouseActionKind }
