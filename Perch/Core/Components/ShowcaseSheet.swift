//
//  ShowcaseSheet.swift
//  Perch
//
//  One shared, fixed-size dialog for every module's "What you get" showcase — so all four
//  (Mouse, Keys, Clipboard, Snippets) are identical in size and chrome. Standard header /
//  content / footer layout like the app's other sheets.
//

import SwiftUI

struct ShowcaseSheet: View {
    let title: String
    let content: AnyView
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text("What you unlock once Accessibility is granted.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460, height: 480)
    }
}
