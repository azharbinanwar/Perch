import SwiftUI

struct SettingGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        if let title {
            GroupBox(title) { content().padding(6) }
        } else {
            GroupBox { content().padding(6) }
        }
    }
}
