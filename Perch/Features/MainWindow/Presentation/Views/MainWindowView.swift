//
//  MainWindowView.swift
//  Perch
//
//  The customize hub — sidebar with one page per feature + General.
//

import SwiftUI

struct MainWindowView: View {
    @State private var selection: SidebarItem = .clipboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            switch selection {
            case .clipboard: ClipboardTabView()
            case .snippets:  SnippetsTabView()
            case .mouse:     MouseTabViewV5()   // V1–V4 all kept
            case .keys:      RemapTabView()
            case .general:   GeneralView()
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }
}
