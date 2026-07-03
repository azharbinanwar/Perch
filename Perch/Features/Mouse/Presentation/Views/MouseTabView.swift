//
//  MouseTabView.swift
//  Perch
//
//  The Mouse tab: an interactive mouse diagram (left) whose selected button is edited in a
//  detail panel (right), per-app profile tiles, plus Pointer / Scrolling / Reliability.
//  Buttons appear as they're scanned; keystroke buttons fill the extra slots.
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
    @State private var addingProfile = false
    @State private var selDiagram = "middle"
    @State private var hoveredProfile: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mouse").font(.title2.bold())
                if !trusted {
                    AccessibilityBanner(message: "Grant Accessibility so scroll, pointer, and buttons can work.")
                }
                buttonsGroup
                pointerGroup
                scrollGroup
                reliabilityGroup
            }
            .padding(20)
        }
        .onAppear { trusted = Permissions.isAccessibilityTrusted }
        .onDisappear { mouse.stopScan() }
        .sheet(isPresented: $addingProfile) {
            AppPickerSheet { ids in ids.forEach { mouse.addProfile(bundleID: $0) } }
        }
        .sheet(item: $clickPick) { pick in
            MouseActionPicker { kind in pickClick(kind, trigger: pick.trigger, phase: pick.phase) }
        }
        .sheet(item: $gesturePick) { pick in
            MouseActionPicker { kind in mouse.setGestureAction(MouseAction(kind: kind), for: pick.button, direction: pick.direction) }
        }
        .sheet(item: $targetPrompt) { targetSheet($0) }
    }

    // MARK: - Per-app profile (horizontal app tiles)

    private var profileStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Per-app profile").font(.system(size: 12.5, weight: .medium))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    defaultTile
                    ForEach(mouse.appProfiles) { appTile($0) }
                    addTile
                }
                .padding(.vertical, 2)
            }
            Text(mouse.isEditingDefault
                 ? "Applies to every app without its own profile."
                 : "Active only while \(mouse.editingProfileName) is frontmost.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var defaultTile: some View {
        profileTile(label: "All apps", selected: mouse.isEditingDefault, action: { mouse.selectProfile(nil) }) {
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: "square.grid.2x2.fill").font(.system(size: 15)).foregroundStyle(.white))
        }
    }

    private func appTile(_ p: MouseProfile) -> some View {
        profileTile(label: p.displayName, selected: mouse.editingBundleID == p.appBundleID,
                    action: { mouse.selectProfile(p.appBundleID) }) {
            appIcon(p.appBundleID)
        }
        .overlay(alignment: .topTrailing) {
            if hoveredProfile == p.appBundleID {
                Button { removeProfile(p) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        .symbolRenderingMode(.palette).foregroundStyle(.white, Color.black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: -2)
            }
        }
        .onHover { hovering in hoveredProfile = hovering ? p.appBundleID : (hoveredProfile == p.appBundleID ? nil : hoveredProfile) }
    }

    private func removeProfile(_ p: MouseProfile) {
        mouse.selectProfile(p.appBundleID)
        mouse.removeEditingProfile()
        hoveredProfile = nil
    }

    private var addTile: some View {
        Button { addingProfile = true } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .foregroundStyle(.secondary).frame(width: 38, height: 38)
                    .overlay(Image(systemName: "plus").font(.system(size: 15)).foregroundStyle(.secondary))
                Text("Add app").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func appIcon(_ bundleID: String?) -> some View {
        if let icon = AppIcon.forBundleID(bundleID) {
            Image(nsImage: icon).resizable().frame(width: 38, height: 38)
        } else {
            RoundedRectangle(cornerRadius: 9).fill(.quaternary).frame(width: 38, height: 38)
                .overlay(Image(systemName: "app.dashed").foregroundStyle(.secondary))
        }
    }

    private func profileTile<Icon: View>(label: String, selected: Bool, action: @escaping () -> Void,
                                         @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                icon()
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2))
                Text(label).font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary).lineLimit(1)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
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
                profileStrip
                Divider()
                detect
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 8) {
                            MouseDiagramView(selected: $selDiagram, isMapped: isMappedHotspot, isActive: isActiveHotspot, onSelect: handleDiagramTap)
                                .padding(.leading, 4)
                                .onChange(of: mouse.addCount) { _, _ in
                                    if let t = mouse.lastAdded, let id = hotspotFor(t) { selDiagram = id }
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
            .padding(6)
        }
    }

    // The right-hand panel: everything the selected button does — its Click / Double / Hold
    // and (for the wheel) its gesture. Wired to the engine by trigger.
    @ViewBuilder
    private var detailPanel: some View {
        let id = selDiagram
        let meta = hotspotMeta(id)
        VStack(alignment: .leading, spacing: 12) {
            panelHeader(meta)
            if meta.locked {
                Text("\(meta.name) is your normal click and can't be remapped. Pick another button on the mouse.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else if let trigger = triggerFor(id) {
                block("CLICK") {
                    let phases = phases(forTrigger: trigger)
                    ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                        if index > 0 { Divider() }
                        panelRow(phase.title, action: mouse.action(for: trigger, phase: phase),
                                 fallback: predefinedLabel(trigger, phase)) {
                            clickPick = ClickPick(trigger: trigger, phase: phase)
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

    private func panelHeader(_ meta: HotspotMeta) -> some View {
        HStack(spacing: 9) {
            Image(systemName: meta.icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26).background(Color.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(meta.name).font(.system(size: 13, weight: .semibold))
                Text(meta.sub).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if let t = triggerFor(selDiagram) {
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


    // MARK: - Card pieces

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

    // Clean detail row: name on the left, current action on the right, a chevron. When unset,
    // a `fallback` (the button's predefined default, e.g. Back/Forward) shows tagged "default".
    private func panelRow(_ title: String, action: MouseAction, fallback: String? = nil,
                          onTap: @escaping () -> Void) -> some View {
        let off = action.kind == .disabled
        let value = off ? (fallback ?? "—") : action.displayLabel
        let muted = off && fallback == nil
        return Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 12, weight: .medium)).frame(width: 100, alignment: .leading)
                Spacer(minLength: 8)
                Text(value).font(.system(size: 12)).foregroundStyle(muted ? .tertiary : .secondary)
                    .lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Buttons that already do something on macOS by default (shown until the user overrides).
    private func predefinedLabel(_ trigger: MouseTrigger, _ phase: ClickPhase) -> String? {
        guard case .single = phase else { return nil }
        switch trigger {
        case .button(3): return "Back"
        case .button(4): return "Forward"
        default:         return nil
        }
    }

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

    // MARK: - Data helpers

    private func buttonNumber(_ trigger: MouseTrigger) -> Int? {
        if case .button(let n) = trigger { return n }
        return nil
    }

    // MARK: - Diagram

    /// Map a diagram hotspot to its trigger (thumb = the first registered keystroke button).
    private func triggerFor(_ id: String) -> MouseTrigger? {
        switch id {
        case "left":   return .button(0)
        case "right":  return .button(1)
        case "middle": return .button(2)
        case "back":   return .button(3)
        case "fwd":    return .button(4)
        case "top":    return additionalTriggers.count > 0 ? additionalTriggers[0] : nil
        case "rup":    return additionalTriggers.count > 1 ? additionalTriggers[1] : nil
        case "rdn":    return additionalTriggers.count > 2 ? additionalTriggers[2] : nil
        default:       return nil
        }
    }

    /// The user's additional buttons — detected physical extras (button 5+) plus registered
    /// keystroke buttons — filling the mouse's extra slots (Top, then right 6/7).
    private var additionalTriggers: [MouseTrigger] {
        let extraPhysical = mouse.detectedButtons.filter {
            if case .button(let n) = $0 { return n >= 5 } else { return false }
        }
        return extraPhysical + mouse.whitelist
    }

    /// Base buttons always show; Back/Forward once detected; the extra slots once an
    /// additional button (detected physical or keystroke) fills them.
    private func isActiveHotspot(_ id: String) -> Bool {
        switch id {
        case "left", "right", "middle": return true
        case "back": return mouse.detectedButtons.contains(.button(3))
        case "fwd":  return mouse.detectedButtons.contains(.button(4))
        case "top":  return additionalTriggers.count > 0
        case "rup":  return additionalTriggers.count > 1
        case "rdn":  return additionalTriggers.count > 2
        default:     return false
        }
    }

    /// Trigger → diagram hotspot (for auto-selecting a freshly detected/registered button).
    private func hotspotFor(_ trigger: MouseTrigger) -> String? {
        switch trigger {
        case .button(0): return "left"
        case .button(1): return "right"
        case .button(2): return "middle"
        case .button(3): return "back"
        case .button(4): return "fwd"
        default:
            guard let i = additionalTriggers.firstIndex(of: trigger), i < 3 else { return nil }
            return ["top", "rup", "rdn"][i]
        }
    }

    private func isMappedHotspot(_ id: String) -> Bool {
        guard let t = triggerFor(id), buttonNumber(t).map({ $0 > 1 }) ?? true else { return false }
        if id == "middle", !mouse.gestures.contains(where: { $0.button == 2 }) {
            return mouse.mapping(for: t) != nil
        }
        return mouse.mapping(for: t) != nil || (id == "middle" && !mouse.gestures.isEmpty)
    }

    /// Clicking a button on the map selects it — the detail panel edits it on the right.
    private func handleDiagramTap(_ id: String) {
        selDiagram = id
    }

    private struct HotspotMeta { let name, sub, icon: String; let locked, gestures: Bool }

    private func hotspotMeta(_ id: String) -> HotspotMeta {
        switch id {
        case "left":   return .init(name: "Left", sub: "Primary click", icon: "cursorarrow.click", locked: true, gestures: false)
        case "right":  return .init(name: "Right", sub: "Secondary click", icon: "cursorarrow.click", locked: true, gestures: false)
        case "middle": return .init(name: "Middle", sub: "Wheel click", icon: "computermouse", locked: false, gestures: true)
        case "top":    return .init(name: "Top", sub: "Top button", icon: "computermouse", locked: false, gestures: false)
        case "back":   return .init(name: "Back", sub: "Side button 4", icon: "arrow.left", locked: false, gestures: false)
        case "fwd":    return .init(name: "Forward", sub: "Side button 5", icon: "arrow.right", locked: false, gestures: false)
        default:       // rup / rdn — additional slots (physical extra or keystroke)
            if let t = triggerFor(id) {
                if case .key = t {
                    return .init(name: t.displayName, sub: "Keystroke button", icon: "keyboard", locked: false, gestures: false)
                }
                return .init(name: t.displayName, sub: "Additional button", icon: "computermouse", locked: false, gestures: false)
            }
            return .init(name: "Extra", sub: "Additional button", icon: "computermouse", locked: false, gestures: false)
        }
    }

    private func phases(forTrigger trigger: MouseTrigger) -> [ClickPhase] {
        if case .key = trigger { return [.single] }
        return ClickPhase.allCases
    }

    private func pickClick(_ kind: MouseActionKind, trigger: MouseTrigger, phase: ClickPhase) {
        if kind.target == .none {
            mouse.setAction(MouseAction(kind: kind), for: trigger, phase: phase)
        } else {
            targetPrompt = MappingTarget(trigger: trigger, phase: phase, kind: kind)
        }
    }

    @ViewBuilder
    private func targetSheet(_ prompt: MappingTarget) -> some View {
        switch prompt.kind.target {
        case .app:
            AppPickerSheet { ids in
                if let bundle = ids.first {
                    mouse.setAction(MouseAction(kind: .openApp, target: bundle), for: prompt.trigger, phase: prompt.phase)
                }
            }
        case .keystroke:
            KeystrokeCaptureSheet { code, mods in
                mouse.setAction(MouseAction(kind: .customKeystroke, keyCode: Int(code), modifiers: mods), for: prompt.trigger, phase: prompt.phase)
            }
        case .url, .file:
            TextTargetSheet(isFile: prompt.kind.target == .file) { text in
                let kind: MouseActionKind = prompt.kind.target == .file ? .openFile : .openURL
                mouse.setAction(MouseAction(kind: kind, target: text), for: prompt.trigger, phase: prompt.phase)
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

private struct ClickPick: Identifiable { let id = UUID(); let trigger: MouseTrigger; let phase: ClickPhase }
private struct GesturePick: Identifiable { let id = UUID(); let button: Int; let direction: GestureDirection }
private struct MappingTarget: Identifiable { let id = UUID(); let trigger: MouseTrigger; let phase: ClickPhase; let kind: MouseActionKind }
