import SwiftUI

struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var onTap: (() -> Void)? = nil          // set → whole row becomes a tappable button
    var compact: Bool = false               // tighter title, for dense action-slot rows
    var indented: Bool = false              // leading indent so a sub-row aligns under its parent's text
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
                Text(title).font(.system(size: compact ? 12 : 13, weight: compact ? .medium : .regular))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .frame(minHeight: compact ? 34 : 0)
        .padding(.leading, indented ? 32 : 0)   // 22 icon + 10 spacing → aligns under the parent text

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
         value: String, placeholder: String = "—", compact: Bool = false, indented: Bool = false,
         onTap: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, icon: icon, onTap: onTap, compact: compact, indented: indented) {
            SettingRowValue(value: value, placeholder: placeholder)
        }
    }
}
