import SwiftUI

struct ReliabilityGroup: View {
    @Environment(MouseViewModel.self) private var mouse

    var body: some View {
        SettingGroup("Reliability") {
            VStack(spacing: 10) {
                SettingRow(title: "Ignore accidental double-clicks",
                           subtitle: "Fixes a worn switch that fires twice on one press.",
                           icon: "hand.tap") {
                    SwitchToggle(isOn: mouse.debounce) { mouse.setDebounce($0) }
                }
                if mouse.debounce {
                    SettingRow(title: "Ignore window", subtitle: "A second click within this time is dropped.") {
                        ValueSlider(value: mouse.debounceMs, range: 20...100, step: 5, format: "%.0f ms") { mouse.setDebounceMs($0) }
                    }
                }
            }
        }
    }
}
