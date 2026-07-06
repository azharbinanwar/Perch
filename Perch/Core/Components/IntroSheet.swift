//
//  IntroSheet.swift
//  Perch
//
//  Generic "watch it happen" intro dialog: header, a stage area where the feature demo
//  plays, a caption line under it, and a tip + Done footer. The stage view owns its own
//  animation; this is just the shared frame (540×480, matching the app's other sheets).
//

import SwiftUI

struct IntroSheet<Stage: View>: View {
    let title: String
    let subtitle: String
    let caption: String        // one line under the stage — updated by the demo as it plays
    let tip: String            // footer hint, e.g. "Try it yourself: …"
    @ViewBuilder var stage: () -> Stage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            VStack(spacing: 14) {
                stage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Always two lines of room — captions of different lengths must never
                // resize the stage above (no layout jump mid-animation).
                Text(caption)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            HStack {
                Text(tip).font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
    }
}
