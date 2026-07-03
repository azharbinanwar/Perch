//
//  MouseCardsV2.swift
//  Perch
//
//  V2 design primitives: a bordered CardGroup container + borderless FlatRow (rows live
//  INSIDE a card, separated by dividers). Gives three clear layers: section → card → rows.
//  V1 components are left untouched.
//

import SwiftUI

/// A bordered rounded container. Put FlatRows inside; use it for single rows or grouped cards.
struct CardGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
    }
}

/// A borderless row (icon · title/subtitle … trailing) meant to sit inside a CardGroup.
struct FlatRow<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .secondary
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

// MARK: - Grouped cards

struct MouseMappingCardV2: View {
    let mapping: MouseMapping
    let onPick: (ClickPhase) -> Void
    let onDelete: () -> Void

    private var phases: [ClickPhase] {
        if case .key = mapping.trigger { return [.single] }
        return ClickPhase.allCases
    }

    var body: some View {
        CardGroup {
            header(icon: triggerIcon, title: mapping.trigger.displayName, onDelete: onDelete)
            ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                Divider()
                Button { onPick(phase) } label: {
                    FlatRow(icon: phase.icon, title: phase.title) {
                        actionTrailing(mapping.action(for: phase).displayLabel)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var triggerIcon: String {
        if case .button(let n) = mapping.trigger { return MouseButton.icon(for: n) }
        return "keyboard"
    }
}

struct MouseGestureCardV2: View {
    let gesture: MouseGesture
    let onPick: (GestureDirection) -> Void
    let onDelete: () -> Void

    var body: some View {
        CardGroup {
            header(icon: "computermouse.fill",
                   title: "\(MouseButton.name(for: gesture.button)) — hold & flick",
                   onDelete: onDelete)
            ForEach(GestureDirection.allCases) { direction in
                Divider()
                Button { onPick(direction) } label: {
                    FlatRow(icon: direction.icon, title: direction.title) {
                        actionTrailing(gesture.action(for: direction).displayLabel)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Shared bits

private func header(icon: String, title: String, onDelete: @escaping () -> Void) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon).foregroundStyle(.secondary)
        Text(title).font(.system(size: 12, weight: .semibold))
        Spacer()
        Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(.secondary) }
            .buttonStyle(.borderless)
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
}

private func actionTrailing(_ label: String) -> some View {
    HStack(spacing: 10) {
        Text(label).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        Image(systemName: "pencil").foregroundStyle(.secondary)
    }
}
