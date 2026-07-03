//
//  PageHeader.swift
//  Perch
//
//  Generic tab header — a title with an optional secondary line (e.g. a device/stat readout).
//  Reusable across settings tabs.
//

import SwiftUI

struct PageHeader: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.bold())
            if let subtitle {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
