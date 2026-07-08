//
//  SettingRow.swift
//  Perch
//
//  Reusable settings row: optional leading icon, title (+ optional subtitle) on the left, any
//  control on the right. Pass `onTap` to make the WHOLE row a button (e.g. a value that opens a
//  picker) — or use the `value:` convenience init, which supplies a "value ›" trailing for you.
//

import SwiftUI

struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var onTap: (() -> Void)? = nil          // set → whole row becomes a tappable button
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        let row = HStack(spacing: 10) {
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

        if let onTap {
            Button(action: onTap) { row.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

/// The trailing content for a value row: current value (or a placeholder) + a chevron.
struct SettingRowValue: View {
    let value: String
    var placeholder = "—"

    var body: some View {
        HStack(spacing: 8) {
            Text(value.isEmpty ? placeholder : value)
                .font(.system(size: 12))
                .foregroundStyle(value.isEmpty ? .tertiary : .secondary)
                .lineLimit(1).truncationMode(.tail)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

extension SettingRow where Trailing == SettingRowValue {
    /// Convenience: a whole-row button showing `value ›` on the right (no manual trailing needed).
    init(title: String, subtitle: String? = nil, icon: String? = nil,
         value: String, placeholder: String = "—", onTap: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, icon: icon, onTap: onTap) {
            SettingRowValue(value: value, placeholder: placeholder)
        }
    }
}
