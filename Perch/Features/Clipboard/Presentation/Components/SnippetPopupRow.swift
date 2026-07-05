//
//  SnippetPopupRow.swift
//  Perch
//
//  A snippet row in the ⌘⇧V popup: note icon (+ quick-pick badge), name, text preview.
//

import SwiftUI

struct SnippetPopupRow: View {
    let snippet: Snippet
    var number: Int? = nil
    var isSelected = false
    var abbreviationBadge: String? = nil   // ";addr" — passed only while text expansion is enabled
    let onPaste: () -> Void
    let onHover: () -> Void

    private var preview: String {
        snippet.text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
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

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(snippet.name).font(.system(size: 13, weight: .medium))
                    if let badge = abbreviationBadge {
                        Text(badge)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                    }
                }
                Text(preview).lineLimit(1).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { if $0 { onHover() } }
        .onTapGesture(count: 2, perform: onPaste)
    }
}
