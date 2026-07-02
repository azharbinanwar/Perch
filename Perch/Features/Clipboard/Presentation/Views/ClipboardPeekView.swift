//
//  ClipboardPeekView.swift
//  Perch
//
//  Menu-bar peek: last N clipboard items (N from settings). Click to copy.
//  Section header lives in MenuContentView.
//

import SwiftUI

struct ClipboardPeekView: View {
    @Environment(ClipboardViewModel.self) private var clipboard
    @Environment(SettingsViewModel.self) private var settings
    var onPick: (ClipboardItem) -> Void

    var body: some View {
        if !clipboard.isRecording {
            note("Recording paused")
        } else if clipboard.recentItems.isEmpty {
            note("Nothing copied yet")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(clipboard.recentItems.prefix(settings.settings.menuItemCount))) { item in
                    ClipboardItemRow(item: item, compact: true) { onPick(item) }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}
