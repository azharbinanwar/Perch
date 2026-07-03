//
//  TileRow.swift
//  Perch
//
//  A full-width filled row: icon · title (+ subtitle) … trailing control (button / toggle /
//  remove). The house style for list items across the app.
//

import SwiftUI

struct TileRow<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .secondary
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}
