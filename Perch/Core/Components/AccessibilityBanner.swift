//
//  AccessibilityBanner.swift
//  Perch
//
//  Reusable warning strip for CGEventTap features (Scroll, Buttons, Remap) when Accessibility
//  isn't granted. Shows a message + an "Open Settings" button that deep-links to the pane.
//

import SwiftUI

struct AccessibilityBanner: View {
    var message = "Perch needs Accessibility permission to control the mouse and keyboard."
    /// Which pane "Open Settings" lands in — pass InputMonitoringService.shared.openSettings
    /// for the Input Monitoring variant. Defaults to Accessibility.
    var openSettings: () -> Void = { AccessibilityService.shared.openSettings() }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.system(size: 12))
            Spacer()
            Button("Open Settings") { openSettings() }
                .font(.system(size: 11))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
