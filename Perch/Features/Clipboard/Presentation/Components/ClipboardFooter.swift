import SwiftUI

struct ClipboardFooter: View {
    let model: ClipboardPopupModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PopupShortcuts.footer) { shortcut in
                Button { action(for: shortcut.keys) } label: {
                    HStack(spacing: 4) {
                        Chip(text: shortcut.keys, size: .small)
                        Text(shortcut.footerLabel ?? "")
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button("Clear All") { model.confirmingClear = true }   // in-panel confirm overlay
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func action(for keys: String) {
        switch keys {
        case "↑ ↓":    model.moveDown()
        case "⇥ / ⇧⇥": model.cycleCategory()
        case "⏎":      model.pasteSelected()
        case "⌘/":     model.toggleHelp()
        case "esc":    model.escape()
        default:       break
        }
    }
}
