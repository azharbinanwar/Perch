//
//  ShortcutColumns.swift
//  Perch
//
//  Two-column layout of the shortcut list with a thin divider. Shared by the
//  popup empty state and the Clipboard control panel.
//

import SwiftUI

struct ShortcutColumns: View {
    var shortcuts: [PopupShortcut] = PopupShortcuts.all

    var body: some View {
        let mid = (shortcuts.count + 1) / 2
        HStack(alignment: .top, spacing: 22) {
            column(Array(shortcuts.prefix(mid)))
            Divider()
            column(Array(shortcuts.suffix(shortcuts.count - mid)))
        }
        .fixedSize()
    }

    private func column(_ items: [PopupShortcut]) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            ForEach(items) { ShortcutRow(keys: $0.keys, label: $0.label) }
        }
    }
}
