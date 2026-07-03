//
//  DebugLogView.swift
//  Perch
//
//  In-app diagnostics: shows the DebugLog buffer (newest at bottom, auto-scrolls) with a
//  Clear button. Drop it into any tab while debugging.
//

import SwiftUI

struct DebugLogView: View {
    private var log = DebugLog.shared

    var body: some View {
        GroupBox("Diagnostics") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(log.entries.count) lines")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(log.entries.joined(separator: "\n"), forType: .string)
                    }.font(.system(size: 11))
                    Button("Clear") { log.clear() }.font(.system(size: 11))
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(log.entries.enumerated()), id: \.offset) { i, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                            }
                            if log.entries.isEmpty {
                                Text("No log yet — toggle a feature and use your mouse.")
                                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 160)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    .onChange(of: log.entries.count) { _, n in
                        withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(n - 1, anchor: .bottom) }
                    }
                }
            }
            .padding(6)
        }
    }
}
