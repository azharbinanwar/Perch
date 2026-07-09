import SwiftUI

struct SwitchToggle: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: onChange))
            .toggleStyle(.switch).labelsHidden()
    }
}
