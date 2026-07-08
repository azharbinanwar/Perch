//
//  PermissionStatusRow.swift
//  Perch
//

import SwiftUI

struct PermissionStatusRow: View {
    let title: String
    let subtitle: String
    let granted: Bool
    let grant: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant…") { grant() }.buttonStyle(.borderedProminent)
            }
        }
    }
}
