import SwiftUI

struct ClipboardSearchBar: View {
    let search: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            if search.isEmpty {
                Text("Type to search").foregroundStyle(.tertiary)
            } else {
                Text(search)
            }
            Spacer()
        }
        .font(.system(size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
