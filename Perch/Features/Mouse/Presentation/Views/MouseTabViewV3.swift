//
//  MouseTabViewV3.swift
//  Perch
//
//  V3 layout: the native macOS System-Settings look — a grouped Form with sections, and each
//  button as an expandable DisclosureGroup (reveal its Click / Double / Hold rows). Same
//  behaviour and view-model as V1/V2; only the presentation differs.
//

import SwiftUI

struct MouseTabViewV3: View {
    @Environment(ScrollViewModel.self) private var scroll
    @Environment(MouseViewModel.self) private var mouse
    @Environment(PointerViewModel.self) private var pointer

    @State private var trusted = Permissions.isAccessibilityTrusted
    @State private var clickPick: ClickPickV3?
    @State private var gesturePick: GesturePickV3?
    @State private var targetPrompt: MappingTargetV3?
    @State private var riskyTrigger: MouseTrigger?

    var body: some View {
        Form {
            if !trusted {
                Section { AccessibilityBanner(message: "Grant Accessibility so scroll, pointer, and buttons can work.") }
            }
            scrollSection
            pointerSection
            buttonsSection
            reliabilitySection
        }
        .formStyle(.grouped)
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

    private var scrollSection: some View {
        Section("Scroll") {
            Toggle(isOn: Binding(get: { scroll.isEnabled }, set: { _ in scroll.toggle() })) {
                labeled("Reverse scroll direction", "Reverses external mouse scroll; trackpad untouched.")
            }
            Toggle(isOn: Binding(get: { scroll.linear }, set: { scroll.setLinear($0) })) {
                labeled("No acceleration (flat)", "Every notch scrolls the same, regardless of speed.")
            }
            LabeledContent {
                sliderControl(scroll.speed, in: 0.25...10, step: 0.25, format: "%.2f×") { scroll.setSpeed($0) }
            } label: { labeled("Scroll speed", "Faster or slower than the system default.") }
            comingSoon("Modifier + scroll = zoom")
            comingSoon("Auto-scroll (hold & move)")
        }
    }

    private var pointerSection: some View {
        Section("Pointer") {
            Toggle(isOn: Binding(get: { pointer.override }, set: { pointer.setOverride($0) })) {
                labeled("Control pointer acceleration", "Override macOS cursor acceleration.")
            }
            if pointer.override {
                LabeledContent {
                    sliderControl(pointer.value, in: 0...20, step: 0.5, format: "%.1f") { pointer.setValue($0) }
                } label: { labeled("Acceleration", "0 = flat 1:1; higher = more.") }
            }
            comingSoon("Pointer speed")
        }
    }

    private var reliabilitySection: some View {
        Section("Reliability") {
            Toggle(isOn: Binding(get: { mouse.debounce }, set: { mouse.setDebounce($0) })) {
                labeled("Ignore accidental double-clicks", "Fixes a worn switch that fires twice.")
            }
            if mouse.debounce {
                LabeledContent {
                    sliderControl(mouse.debounceMs, in: 20...100, step: 5, format: "%.0f ms") { mouse.setDebounceMs($0) }
                } label: { labeled("Ignore window", "Drop a second click within this time.") }
            }
            comingSoon("Swap primary / secondary")
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        Section("Buttons") {
            Toggle(isOn: Binding(get: { mouse.isEnabled }, set: { mouse.setEnabled($0) })) {
                labeled("Enable button mapping", "Assign buttons to shortcuts, actions, gestures.")
            }

            HStack {
                Button(mouse.detectingButtons ? "Stop" : "Detect a button") { mouse.toggleButtonDetect() }
                Button("Add keystroke button") { mouse.startKeyCapture() }
                Spacer()
                if mouse.detectingButtons {
                    Text("Press a button").font(.system(size: 11)).foregroundStyle(.secondary)
                } else if !mouse.detectedButtons.isEmpty {
                    Button("Clear") { mouse.clearDetected() }
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

            LabeledContent("Left / Right") { Text("Normal click").foregroundStyle(.secondary) }

            ForEach(mouse.mappings) { mapping in
                DisclosureGroup {
                    ForEach(phases(for: mapping), id: \.self) { phase in
                        Button { clickPick = ClickPickV3(mappingID: mapping.id, phase: phase) } label: {
                            LabeledContent(phase.title) {
                                Text(mapping.action(for: phase).displayLabel).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Remove", role: .destructive) { mouse.removeMapping(mapping.id) }
                } label: {
                    Label(mapping.trigger.displayName, systemImage: triggerIcon(mapping.trigger))
                }
            }
            ForEach(mouse.availableTriggers, id: \.self) { trigger in
                Button { requestAdd(trigger) } label: {
                    Label("Add \(trigger.displayName)", systemImage: "plus.circle")
                }
            }

            ForEach(mouse.gestures) { gesture in
                DisclosureGroup {
                    ForEach(GestureDirection.allCases) { direction in
                        Button { gesturePick = GesturePickV3(gestureID: gesture.id, direction: direction) } label: {
                            LabeledContent(direction.title) {
                                Text(gesture.action(for: direction).displayLabel).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Remove", role: .destructive) { mouse.removeGesture(gesture.id) }
                } label: {
                    Label("\(MouseButton.name(for: gesture.button)) — hold & flick", systemImage: "hand.draw")
                }
            }
            ForEach(mouse.availableGestureButtons, id: \.self) { button in
                Button { mouse.addGesture(for: button) } label: {
                    Label("Add gesture on \(MouseButton.name(for: button))", systemImage: "plus.circle")
                }
            }

            comingSoon("Per-app profiles")
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

    private func labeled(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
            Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func sliderControl(_ value: Double, in range: ClosedRange<Double>, step: Double, format: String,
                               action: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: action), in: range, step: step).frame(width: 130)
            Text(String(format: format, value)).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
        }
    }

    private func comingSoon(_ title: String) -> some View {
        LabeledContent {
            Text("Coming soon").font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 7).padding(.vertical, 2).background(.quaternary, in: Capsule())
        } label: {
            Text(title).foregroundStyle(.secondary)
        }
        .opacity(0.6)
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
            targetPrompt = MappingTargetV3(mappingID: id, phase: phase, kind: kind)
        }
    }

    @ViewBuilder
    private func targetSheet(_ prompt: MappingTargetV3) -> some View {
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

private struct ClickPickV3: Identifiable { let id = UUID(); let mappingID: UUID; let phase: ClickPhase }
private struct GesturePickV3: Identifiable { let id = UUID(); let gestureID: UUID; let direction: GestureDirection }
private struct MappingTargetV3: Identifiable { let id = UUID(); let mappingID: UUID; let phase: ClickPhase; let kind: MouseActionKind }
