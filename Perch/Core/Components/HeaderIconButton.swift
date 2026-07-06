//
//  HeaderIconButton.swift
//  Perch
//
//  The one icon-only action button for page headers. Every header uses this, so all icons
//  share the same size and footprint — no per-page drift. Destructive actions render red;
//  the tooltip carries the label the icon no longer shows.
//

import SwiftUI

struct HeaderIconButton: View {
    let icon: String
    let help: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 20, height: 16)   // fixed footprint → identical buttons everywhere
        }
        .help(help)
    }
}
