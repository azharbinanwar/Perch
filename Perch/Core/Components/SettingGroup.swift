//
//  SettingGroup.swift
//  Perch
//
//  Generic settings box: a GroupBox with an optional title and consistent inner padding, so every
//  section matches by construction (no per-box `.padding(6)` to forget). Pairs with SettingRow.
//

import SwiftUI

struct SettingGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        if let title {
            GroupBox(title) { content().padding(6) }
        } else {
            GroupBox { content().padding(6) }
        }
    }
}
