//
//  DebugLogBox.swift
//  Perch
//

import SwiftUI
import AppKit

struct DebugLogBox: View {
    var body: some View {
        SettingGroup("Debug log") {
            VStack(alignment: .leading, spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(DiagLog.shared.text.isEmpty ? "Engine diagnostics appear here." : DiagLog.shared.text)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("logEnd")
                    }
                    .frame(height: 320)
                    .onChange(of: DiagLog.shared.text) { _, _ in
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
                HStack {
                    Spacer()
                    Button("Clear") { DiagLog.shared.clear() }
                        .disabled(DiagLog.shared.text.isEmpty)
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(DiagLog.shared.text, forType: .string)
                    }
                    .disabled(DiagLog.shared.text.isEmpty)
                }
            }
        }
    }
}
