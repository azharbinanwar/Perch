import SwiftUI

// A labeled key-record field: tap the box to start/stop recording. Shows the captured value or a
// placeholder, with a hint underneath. The TO field reuses it with a trailing "pick action" button.
struct RecordField<Accessory: View>: View {
    let label: String
    let text: String
    let active: Bool
    let placeholder: Bool
    let hint: String
    let onTap: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
            HStack(spacing: 8) {
                Button(action: onTap) { box }.buttonStyle(.plain)
                accessory()
            }
            Text(hint).font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
    }

    private var box: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(placeholder ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity).frame(height: 52).padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(active ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: active ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if active {
                    Image(systemName: "circle.fill").font(.system(size: 8))
                        .foregroundStyle(.green).symbolEffect(.pulse).padding(8)
                }
            }
    }
}

// FROM has no accessory — this init lets callers omit the trailing closure.
extension RecordField where Accessory == EmptyView {
    init(label: String, text: String, active: Bool, placeholder: Bool, hint: String,
         onTap: @escaping () -> Void) {
        self.init(label: label, text: text, active: active, placeholder: placeholder,
                  hint: hint, onTap: onTap) { EmptyView() }
    }
}
