//
//  SettingRow.swift
//  Perch
//
//  Reusable settings row: title (+ optional subtitle) on the left, any control on the right.
//

import SwiftUI

struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
    }
}
