//
//  MouseMappingCard.swift
//  Perch
//
//  A mapped button as a flat group: header (button + remove) then one flat TileRow per click
//  phase (Click / Double-click / Hold) with its action inline. Tapping a row opens the picker.
//  Keystroke buttons only offer the single Click phase.
//

import SwiftUI

struct MouseMappingCard: View {
    let mapping: MouseMapping
    let onPick: (ClickPhase) -> Void
    let onDelete: () -> Void

    private var phases: [ClickPhase] {
        if case .key = mapping.trigger { return [.single] }   // a keystroke can't double/hold
        return ClickPhase.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(mapping.trigger.displayName).font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            ForEach(phases) { phase in
                Button { onPick(phase) } label: {
                    TileRow(icon: phase.icon, title: phase.title) {
                        HStack(spacing: 10) {
                            Text(mapping.action(for: phase).displayLabel)
                                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            Image(systemName: "pencil").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var icon: String {
        switch mapping.trigger {
        case .button(let n): return MouseButton.icon(for: n)
        case .key:           return "keyboard"
        }
    }
}
