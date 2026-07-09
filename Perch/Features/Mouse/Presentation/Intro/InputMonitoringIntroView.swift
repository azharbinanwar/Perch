import SwiftUI

struct InputMonitoringIntroView: View {
    private let points: [(icon: String, title: String, detail: String)] = [
        ("computermouse", "See your mouse",
         "Perch reads the connected device's name and how many buttons it has."),
        ("dot.viewfinder", "Scan extra buttons",
         "Detects side buttons (4, 5, 6…) so you can map them — including ones that type a shortcut."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Input Monitoring is optional. Remapping, gestures and scrolling all work without it — it only adds device detection.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(points, id: \.title) { point in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: point.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.title).font(.system(size: 13, weight: .semibold))
                        Text(point.detail)
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
