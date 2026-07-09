import SwiftUI

struct ClipboardCategoryBar: View {
    let model: ClipboardPopupModel

    var body: some View {
        Picker("", selection: Binding(get: { model.category }, set: { model.setCategory($0) })) {
            ForEach(model.availableCategories) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
