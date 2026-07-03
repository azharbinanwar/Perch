//
//  MouseGestureCard.swift
//  Perch
//
//  A gesture button as a flat group (no nested card): a small header (button + remove) then
//  one flat TileRow per direction with its action shown inline. Tapping a row opens the picker.
//

import SwiftUI

struct MouseGestureCard: View {
    let gesture: MouseGesture
    let onPick: (GestureDirection) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "computermouse.fill").foregroundStyle(.secondary)
                Text("\(MouseButton.name(for: gesture.button)) — hold & flick")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            ForEach(GestureDirection.allCases) { direction in
                Button { onPick(direction) } label: {
                    TileRow(icon: direction.icon, title: direction.title) {
                        HStack(spacing: 10) {
                            Text(gesture.action(for: direction).displayLabel)
                                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            Image(systemName: "pencil").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
