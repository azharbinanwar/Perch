import SwiftUI

struct ScrollGroup: View {
    @Environment(MouseViewModel.self) private var mouse
    private var profileLabel: String { mouse.isEditingDefault ? "All apps" : mouse.editingProfileName }

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
                                   : "Held only while you want the boost.") {
                        Picker("", selection: Binding(get: { mouse.editingScroll.turboKey },
                                                      set: { key in mouse.updateScroll { $0.turboKey = key } })) {
                            ForEach(TurboKey.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                    }
                    SettingRow(title: "Turbo speed", subtitle: "Multiplies your scroll speed while the key is held.") {
                        ValueSlider(value: mouse.editingScroll.turboSpeed, range: 2...10, step: 0.5, format: "%.1f×") { v in
                            mouse.updateScroll { $0.turboSpeed = v }
                        }
                    }
                }
                Divider()
                SettingRow(title: "Auto-scroll",
                           subtitle: "Long-press the middle button, then move to scroll. Release to keep scrolling; any click stops.",
                           icon: "arrow.down.circle") {
                    SwitchToggle(isOn: mouse.editingScroll.autoOn) { on in mouse.updateScroll { $0.autoOn = on } }
                }
                if mouse.editingScroll.autoOn {
                    SettingRow(title: "Sensitivity") {
                        ValueSlider(value: mouse.editingScroll.autoSpeed, range: 0.1...4, step: 0.05, format: "%.2f×") { v in
                            mouse.updateScroll { $0.autoSpeed = v }
                        }
                    }
                }
            }
        }
    }
}
