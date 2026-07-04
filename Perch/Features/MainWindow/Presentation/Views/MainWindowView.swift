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
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)   // no collapse control — always-visible native sidebar
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
