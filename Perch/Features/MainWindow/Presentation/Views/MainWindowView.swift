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
                // Standard macOS sidebar: plain template glyphs (no color tiles), slightly
                // larger than the default, in a fixed frame so all labels align.
                Label {
                    Text(item.title).font(.system(size: 13))
                } icon: {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .tag(item)
            }
            .navigationSplitViewColumnWidth(215)   // System-Settings-standard sidebar width
        } detail: {
            switch selection {
            case .clipboard: ClipboardTabView()
            case .snippets:  SnippetsTabView()
            case .mouse:     MouseTabView()
            case .keys:      RemapTabView()
            case .general:   GeneralView()
            }
        }
        .frame(minWidth: 640, minHeight: 580)   // match onboarding so the window is one consistent height
    }
}
