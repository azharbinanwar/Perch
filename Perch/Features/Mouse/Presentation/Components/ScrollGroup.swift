import SwiftUI

struct ScrollGroup: View {
    @Environment(MouseViewModel.self) private var mouse
    @State private var autoConflictWarn = false
    private var profileLabel: String { mouse.isEditingDefault ? "All apps" : mouse.editingProfileName }

    /// The Hold action currently set on the auto-scroll button, if any — it's what turning
    /// auto-scroll on will pause.
    private var autoHoldAction: Action? {
        let a = mouse.action(for: .button(mouse.editingScroll.autoButton), phase: .hold)
        return a.kind == .disabled ? nil : a
    }

    var body: some View {
        SettingGroup("Scroll — \(profileLabel)") {
            VStack(spacing: 10) {
                SettingRow(title: "Reverse scroll direction",
                           subtitle: "Reverses external mouse scroll; the trackpad is left untouched.",
                           icon: "arrow.up.arrow.down") {
                    SwitchToggle(isOn: mouse.editingScroll.reversed) { on in mouse.updateScroll { $0.reversed = on } }
                }
                Divider()
                SettingRow(title: "Smooth scrolling",
                           subtitle: "Each wheel tick glides instead of jumping — trackpad feel on a notchy wheel.",
                           icon: "scroll") {
                    SwitchToggle(isOn: mouse.editingScroll.smooth) { on in mouse.updateScroll { $0.smooth = on } }
                }
                Divider()
                SettingRow(title: "No acceleration (flat)",
                           subtitle: "Every notch scrolls the same amount, regardless of how fast you spin.",
                           icon: "equal") {
                    SwitchToggle(isOn: mouse.editingScroll.linear) { on in mouse.updateScroll { $0.linear = on } }
                }
                Divider()
                SettingRow(title: "Scroll speed", subtitle: "Faster or slower than the system default.",
                           icon: "speedometer") {
                    ValueSlider(value: mouse.editingScroll.speed, range: 0.25...10, step: 0.25, format: "%.2f×") { v in
                        mouse.updateScroll { $0.speed = v }
                    }
                }
                Divider()
                SettingRow(title: "Turbo scroll",
                           subtitle: mouse.editingScroll.turboOn
                               ? "Hold \(mouse.editingScroll.turboKey.rawValue.prefix(1)) while scrolling for \(String(format: "%.1f", mouse.editingScroll.turboSpeed))× speed."
                               : "Hold a key while scrolling to go extra fast — for very long pages.",
                           icon: "hare") {
                    SwitchToggle(isOn: mouse.editingScroll.turboOn) { on in mouse.updateScroll { $0.turboOn = on } }
                }
                if mouse.editingScroll.turboOn {
                    SettingRow(title: "Hold key",
                               subtitle: mouse.editingScroll.turboKey == .control
                                   ? "⌃ can conflict with macOS scroll-zoom if you enabled it in Accessibility."
                                   : "Held only while you want the boost.",
                               indented: true) {
                        Picker("", selection: Binding(get: { mouse.editingScroll.turboKey },
                                                      set: { key in mouse.updateScroll { $0.turboKey = key } })) {
                            ForEach(TurboKey.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                    }
                    SettingRow(title: "Turbo speed", subtitle: "Multiplies your scroll speed while the key is held.", indented: true) {
                        ValueSlider(value: mouse.editingScroll.turboSpeed, range: 2...10, step: 0.5, format: "%.1f×") { v in
                            mouse.updateScroll { $0.turboSpeed = v }
                        }
                    }
                }
                Divider()
                SettingRow(title: "Auto-scroll",
                           subtitle: "Long-press the middle button, then move to scroll. Release to keep scrolling; any click stops.",
                           icon: "arrow.down.circle") {
                    SwitchToggle(isOn: mouse.editingScroll.autoOn) { on in
                        // Turning on while the button already has a Hold action → warn first (it'll be
                        // paused). No action set → just turn on. Turning off is always immediate.
                        if on, autoHoldAction != nil {
                            autoConflictWarn = true
                        } else {
                            mouse.updateScroll { $0.autoOn = on }
                        }
                    }
                }
                if mouse.editingScroll.autoOn {
                    SettingRow(title: "Sensitivity", indented: true) {
                        ValueSlider(value: mouse.editingScroll.autoSpeed, range: 0.1...4, step: 0.05, format: "%.2f×") { v in
                            mouse.updateScroll { $0.autoSpeed = v }
                        }
                    }
                }
                InfoNote(systemImage: "lightbulb",
                         text: "Some apps — JetBrains IDEs like Android Studio, and other Java-based apps — ignore scroll speed, turbo and smooth. For those, add a per-app profile with Smooth off for clean native scrolling.")
            }
        }
        .alert("Turn on Auto-scroll?", isPresented: $autoConflictWarn) {
            Button("Cancel", role: .cancel) {}
            Button("Turn On") { mouse.updateScroll { $0.autoOn = true } }
        } message: {
            Text("The middle button's Hold action\(autoHoldAction.map { " — \($0.displayLabel)" } ?? "") pauses while Auto-scroll is on. It returns when you turn Auto-scroll off. Click and double-click keep working.")
        }
    }
}
