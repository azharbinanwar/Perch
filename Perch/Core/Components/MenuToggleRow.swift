//
//  MenuToggleRow.swift
//  Perch
//
//  Reusable menu-bar row: title (optional subtitle) on the left, a switch on the right.
//

import SwiftUI

struct MenuToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var subtitleColor: Color = .secondary
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(subtitleColor)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: { _ in onToggle() }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
