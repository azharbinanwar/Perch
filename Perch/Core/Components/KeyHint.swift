//
//  KeyHint.swift
//  Perch
//
//  Keycap chip + short label (e.g. [↑ ↓] navigate). One widget for every
//  footer hint so pickers, panels and sheets all read the same.
//

import SwiftUI

struct KeyHint: View {
    let keys: String
    let label: String
    var size: Chip.Size = .small

    var body: some View {
        HStack(spacing: 4) {
            Chip(text: keys, size: size)
            Text(label)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
