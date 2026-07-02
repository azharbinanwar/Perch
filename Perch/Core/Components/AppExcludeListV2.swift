//
//  AppExcludeListV2.swift
//  Perch
//
//  Trial redesign of the app-exclusion editor — compact chips that wrap, instead of
//  a sparse list. Revert: swap `AppExcludeListV2` back to `AppExcludeList` at call sites.
//

import SwiftUI

struct AppExcludeListV2: View {
    let title: String
    let subtitle: String
    let bundleIDs: [String]
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void

    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 12) {
                ForEach(bundleIDs, id: \.self) { id in
                    ExcludedAppTile(id: id) { onRemove(id) }
                }
                addTile
            }
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerSheet { ids in ids.forEach(onAdd) }
        }
    }

    private var addTile: some View {
        Button { showingPicker = true } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 26, weight: .light))
                Text("Add").font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .frame(width: 76, height: 78)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
    }
}

/// A selected app: Finder-style big icon over name; remove ✕ appears on hover.
private struct ExcludedAppTile: View {
    let id: String
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let icon = AppIcon.forBundleID(id) {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -2)   // sit on the icon's corner, badge-style
                }
            }

            Text(AppIcon.name(forBundleID: id) ?? id)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 76)
        .padding(.vertical, 6)
        .onHover { hovering = $0 }
    }
}
