import SwiftUI

struct ClipboardClearConfirmOverlay: View {
    let onCancel: () -> Void
    let onClear: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture(perform: onCancel)

            // Mimics a native macOS alert: no icon, centered bold title + message, then two
            // full-width rounded buttons (Cancel bordered, default prominent).
            VStack(spacing: 6) {
                Text("Clear all clipboard items?")
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("This permanently removes every item in your clipboard history. This can't be undone.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button(action: onClear) { Text("Clear").frame(maxWidth: .infinity) }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                    Button(action: onCancel) { Text("Cancel").frame(maxWidth: .infinity) }
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding(.top, 12)
            }
            .padding(18)
            .frame(width: 260)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
        }
    }
}
