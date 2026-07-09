import SwiftUI

// Self-contained action-slot row (Click / Hold / Double, plus locked variants). Owns its own
// value+chevron trailing so it never depends on SettingRow — the two evolve independently.
struct ActionSlotRow<Subtitle: View, Trailing: View>: View {
    let title: String
    var onTap: (() -> Void)? = nil
    @ViewBuilder let subtitle: () -> Subtitle
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        let row = HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                subtitle()
            }
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 36)

        if let onTap {
            Button(action: onTap) { row.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

extension ActionSlotRow where Subtitle == EmptyView {
    init(title: String, onTap: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(title: title, onTap: onTap, subtitle: { EmptyView() }, trailing: trailing)
    }
}

// Default trailing: current value + a chevron; empty value shows a muted placeholder.
struct ActionSlotValue: View {
    let value: String
    var placeholder = "—"

    var body: some View {
        HStack(spacing: 8) {
            Text(value.isEmpty ? placeholder : value)
                .font(.system(size: 12)).foregroundStyle(value.isEmpty ? .tertiary : .secondary)
                .lineLimit(1).truncationMode(.tail)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
    }
}

// Convenience: whole-row tap with the value+chevron trailing built in (no subtitle).
extension ActionSlotRow where Subtitle == EmptyView, Trailing == ActionSlotValue {
    init(title: String, value: String, placeholder: String = "—", onTap: @escaping () -> Void) {
        self.init(title: title, onTap: onTap) { ActionSlotValue(value: value, placeholder: placeholder) }
    }
}
