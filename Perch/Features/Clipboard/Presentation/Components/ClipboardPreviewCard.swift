//
//  ClipboardPreviewCard.swift
//  Perch
//
//  Full-content preview of a clipboard item (Quick-Look style): source app + time
//  header, then the whole text, scrollable and selectable.
//

import SwiftUI

struct ClipboardPreviewCard: View {
    let item: ClipboardItem
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 10) {
                header
                Divider()
                ScrollView {
                    Text(item.text)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(width: 480, height: 360)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = AppIcon.forBundleID(item.sourceApp) {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            Text(AppIcon.name(forBundleID: item.sourceApp) ?? "Clipboard")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(item.copiedAt, format: .relative(presentation: .named))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
