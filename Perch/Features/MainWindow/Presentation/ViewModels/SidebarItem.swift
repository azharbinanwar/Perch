//
//  SidebarItem.swift
//  Perch
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case clipboard
    case snippets
    case mouse
    case keys
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .snippets:  "Snippets"
        case .mouse:     "Mouse"
        case .keys:      "Keys"
        case .general:   "General"
        }
    }

    var icon: String {
        switch self {
        case .clipboard: "doc.on.clipboard.fill"
        case .snippets:  "text.quote"
        case .mouse:     "computermouse.fill"
        case .keys:      "keyboard.fill"
        case .general:   "gearshape.fill"
        }
    }

    /// System-Settings-style tile color behind the white glyph.
    var tint: Color {
        switch self {
        case .clipboard: .orange
        case .snippets:  .green
        case .mouse:     .blue
        case .keys:      .purple
        case .general:   .gray
        }
    }
}
