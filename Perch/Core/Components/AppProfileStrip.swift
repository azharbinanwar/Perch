//
//  AppProfileStrip.swift
//  Perch
//
//  Generic horizontal per-app profile picker: a "Default / All apps" gradient tile, one tile
//  per app (real icon, hover to remove), and an "Add app" tile. VM-agnostic — the caller passes
//  the items and callbacks. Shared by the Mouse and Keys tabs.
//

import SwiftUI

struct AppProfileStrip: View {
    struct Item: Identifiable {
        let bundleID: String?          // nil = Default / All apps
        let name: String
        var id: String { bundleID ?? "__default__" }
    }

    let items: [Item]                  // Default first, then app profiles
    let selectedBundleID: String?
    let subtitle: String
    var onSelect: (String?) -> Void
    var onAdd: () -> Void
    var onRemove: (String) -> Void
    var onInfo: (() -> Void)? = nil    // each tab shows ITS OWN profile demo here

    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Per-app profile").font(.system(size: 12.5, weight: .medium))
                if let onInfo {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("See how per-app profiles work")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { tile($0) }
                    addTile
                }
                .padding(.vertical, 2)
            }
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func tile(_ item: Item) -> some View {
        let selected = item.bundleID == selectedBundleID
        return Button { onSelect(item.bundleID) } label: {
            VStack(spacing: 5) {
                icon(item)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2))
                Text(item.name).font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary).lineLimit(1)
            }
            .frame(width: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if let bundleID = item.bundleID, hovered == item.id {
                Button { onRemove(bundleID) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        .symbolRenderingMode(.palette).foregroundStyle(.white, Color.black.opacity(0.55))
                }
                .buttonStyle(.plain).offset(x: -8, y: -2)
            }
        }
        .onHover { h in hovered = h ? item.id : (hovered == item.id ? nil : hovered) }
    }

    @ViewBuilder
    private func icon(_ item: Item) -> some View {
        // Real app icons ship with a built-in transparent margin inside their canvas, so the
        // selection border shows a gap around the artwork. Drawn tiles get the same gap: a
        // smaller square centered in the same outer frame — every tile breathes identically.
        if item.bundleID == nil {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "square.grid.2x2.fill").font(.system(size: 17)).foregroundStyle(.white))
                .frame(width: 55, height: 55)
        } else if let nsIcon = AppIcon.forBundleID(item.bundleID) {
            Image(nsImage: nsIcon).resizable().frame(width: 55, height: 55)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(.quaternary).frame(width: 46, height: 46)
                .overlay(Image(systemName: "app.dashed").foregroundStyle(.secondary))
                .frame(width: 55, height: 55)
        }
    }

    private var addTile: some View {
        Button(action: onAdd) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .foregroundStyle(.secondary).frame(width: 46, height: 46)
                    .overlay(Image(systemName: "plus").font(.system(size: 17)).foregroundStyle(.secondary))
                    .frame(width: 55, height: 55)
                Text("Add app").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
