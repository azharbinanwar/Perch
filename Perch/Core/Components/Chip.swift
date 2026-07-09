import SwiftUI

struct Chip: View {
    enum Size { case small, regular }

    let text: String
    var size: Size = .regular
    var monospaced: Bool = false

    private var fontSize: CGFloat { size == .small ? 10 : 13 }
    private var hPad: CGFloat { size == .small ? 6 : 10 }
    private var vPad: CGFloat { size == .small ? 1 : 4 }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium, design: monospaced ? .monospaced : .rounded))
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .background(.quaternary.opacity(0.4), in: Capsule())
    }
}
