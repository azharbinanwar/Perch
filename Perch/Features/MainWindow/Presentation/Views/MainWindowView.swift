//
//  MainWindowView.swift
//  Perch
//
//  The customize hub — a native sidebar with one page per feature + General.
//

import SwiftUI

struct MainWindowView: View {
    @State private var selection: SidebarItem = .clipboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                // System-Settings look: same-size white glyph on a colored rounded tile —
                // uniform tiles read cleaner than raw glyphs of wildly different shapes.
                Label {
                    Text(item.title)
                } icon: {
                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 21, height: 21)
                        .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 5.5))
                }
                .tag(item)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            switch selection {
            case .clipboard: ClipboardTabView()
            case .snippets:  SnippetsTabView()
            case .mouse:     MouseTabView()
            case .keys:      RemapTabView()
            case .general:   GeneralView()
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }
}
