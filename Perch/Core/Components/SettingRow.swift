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
    var icon: String? = nil          // optional leading SF Symbol
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }
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
