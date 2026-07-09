import SwiftUI

struct PermissionStatusRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let granted: Bool
    let grant: () -> Void

    var body: some View {
        SettingRow(title: title, subtitle: subtitle, icon: icon) {
            if granted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Granted")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
            } else {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Needed")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.warning)
                    Button("Grant") { grant() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.warning)
                }
            }
        }
    }
}
