//
//  ClipboardItemRow.swift
//  Perch
//
//  One clipboard row. Single clean line: source-app icon (quick-pick number as a badge
//  on its corner) + inline smart-type marker + one-line preview + hover actions / time.
//  - compact → menu peek (icon + text, tap = copy)
//  - full    → popup (density-sized, hover Copy/Pin/Delete, double-click = copy)
//

import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var compact = false                // menu peek — fixed small look, ignores density
    var density: RowDensity = .regular // popup — user-selectable
    var number: Int? = nil
    var isSelected = false
    var highlightsOnHover = true
    let onCopy: () -> Void
    var onDelete: (() -> Void)? = nil
    var onPin: (() -> Void)? = nil
    var onHover: (() -> Void)? = nil

    @State private var hovering = false

    private var highlighted: Bool { isSelected || (highlightsOnHover && hovering) }
    private var iconSize: CGFloat { compact ? 16 : density.iconSize }
    private var fontSize: CGFloat { compact ? 12 : density.fontSize }
    private var lineLimit: Int { compact ? 1 : density.lineLimit }
    private var verticalPadding: CGFloat { compact ? 5 : density.verticalPadding }
    private var showsTime: Bool { !compact && density.showsTime }
    private var kind: ClipboardKind { ClipboardKind.detect(item.text) }

    private var previewFont: Font {
        if case .code = kind { return .system(size: fontSize, design: .monospaced) }
        return .system(size: fontSize)
    }
    private var previewColor: Color {
        switch kind {
        case .link, .email: return .accentColor
        default: return .primary
        }
    }

    /// Collapse all whitespace/newlines so every row is one clean line.
    private var preview: String {
        item.text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var body: some View {
        HStack(spacing: 10) {
            icon
            HStack(spacing: 5) {
                inlineTypeIcon
                Text(preview)
                    .lineLimit(lineLimit)
                    .font(previewFont)
                    .foregroundStyle(previewColor)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, 10)
        .background(highlighted ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0; if $0 { onHover?() } }
        .onTapGesture(count: compact ? 1 : 2, perform: onCopy)
    }

    // MARK: - Icon (with quick-pick number badge)

    private var icon: some View {
        sourceIcon
            .frame(width: iconSize, height: iconSize)
            .overlay(alignment: .bottomTrailing) {
                if let number {
                    Text("\(number)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 13, height: 13)
                        .background(Color.accentColor, in: Circle())
                        .overlay(Circle().stroke(.background, lineWidth: 1.5))
                        .offset(x: 4, y: 4)
                }
            }
    }

    /// Small inline type marker before the text (like a RichText leading span).
    @ViewBuilder
    private var inlineTypeIcon: some View {
        switch kind {
        case .color(let color):
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.quaternary))
        case .link:
            Image(systemName: "globe").font(.system(size: 11)).foregroundStyle(.secondary)
        case .email:
            Image(systemName: "envelope.fill").font(.system(size: 11)).foregroundStyle(.secondary)
        case .code:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        case .text:
            EmptyView()
        }
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let appIcon = AppIcon.forBundleID(item.sourceApp) {
            Image(nsImage: appIcon).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Trailing (hover actions, else pin + time)

    @ViewBuilder
    private var trailing: some View {
        if !compact, highlighted {
            HStack(spacing: 2) {
                if let onPin {
                    iconButton(item.isPinned ? "pin.slash" : "pin",
                               help: item.isPinned ? "Unpin" : "Pin", action: onPin)
                }
                iconButton("doc.on.doc", help: "Copy", action: onCopy)
                if let onDelete {
                    iconButton("trash", help: "Delete", action: onDelete)
                }
            }
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 5) {
                if item.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                if showsTime {
                    Text(item.copiedAt, format: .relative(presentation: .named))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
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
