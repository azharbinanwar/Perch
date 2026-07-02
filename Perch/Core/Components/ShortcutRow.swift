//
//  ShortcutRow.swift
//  Perch
//
//  Reusable keycap + description row for a Grid. Used by the popup cheat-sheet
//  and the Clipboard control panel so both stay visually identical.
//

import SwiftUI

struct ShortcutRow: View {
    let keys: String
    let label: String

    var body: some View {
        GridRow {
            Text(keys)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .gridColumnAlignment(.leading)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
