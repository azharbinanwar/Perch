import SwiftUI

struct IntPicker<Content: View>: View {
    let selection: Binding<Int>
    @ViewBuilder let content: () -> Content

    var body: some View {
        Picker("", selection: selection) { content() }
            .labelsHidden()
            .frame(width: 130)
    }
}
