import SwiftUI

struct ClipboardBanner: View {
    let icon: String
    let text: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.orange)
            Text(text).font(.system(size: 12))
            Spacer()
            Button(actionLabel, action: action).font(.system(size: 11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
    }
}
