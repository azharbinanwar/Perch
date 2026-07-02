//
//  ClipboardItemRow.swift
//  Perch
//
//  One clipboard row for both surfaces:
//  - compact  → menu-bar peek: single line, tap = copy
//  - full     → window history: icon + 2-line + time, hover Copy/Delete, double-click = copy
//

import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var compact = false
    var number: Int? = nil             // popup quick-pick digit (⌘1–9)
    var showsIcon = true               // false in popup (numbers replace the icon)
    var isSelected = false             // external selection (popup)
    var highlightsOnHover = true       // false in popup: selection drives the highlight
    let onCopy: () -> Void
    var onDelete: (() -> Void)? = nil
    var onPin: (() -> Void)? = nil     // pin/unpin toggle (popup)
    var onHover: (() -> Void)? = nil   // popup: hovering moves the selection

    @State private var hovering = false

    private var highlighted: Bool { isSelected || (highlightsOnHover && hovering) }

    var body: some View {
        HStack(spacing: 10) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .lineLimit(compact ? 1 : 2)
                    .font(.system(size: compact ? 12 : 13))
                    .foregroundStyle(.primary)
                if !compact {
                    Text(item.copiedAt, format: .relative(presentation: .named))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                if item.isPinned, !(highlighted && onPin != nil) {
                    Image(systemName: "pin.fill").font(.system(size: 10))
                }
                if !compact, highlighted {
                    if let onPin {
                        iconButton(item.isPinned ? "pin.slash" : "pin",
                                   help: item.isPinned ? "Unpin" : "Pin", action: onPin)
                    }
                    iconButton("doc.on.doc", help: "Copy", action: onCopy)
                    if let onDelete {
                        iconButton("trash", help: "Delete", action: onDelete)
                    }
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, compact ? 5 : 7)
        .padding(.horizontal, compact ? 12 : 10)
        .background(highlighted ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0; if $0 { onHover?() } }
        .onTapGesture(count: compact ? 1 : 2, perform: onCopy)
    }

    @ViewBuilder
    private var leading: some View {
        HStack(spacing: 6) {
            if let number {
                Text("\(number)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            sourceIcon.frame(width: 16, height: 16)
        }
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let icon = AppIcon.forBundleID(item.sourceApp) {
            Image(nsImage: icon).resizable().frame(width: 16, height: 16)
        } else if !compact && showsIcon {
            Image(systemName: "doc.plaintext").font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12)).frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
