//
//  SidebarItem.swift
//  Perch
//

enum SidebarItem: String, CaseIterable, Identifiable {
    case clipboard
    case scroll
    case keys
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .scroll:    "Scroll"
        case .keys:      "Keys"
        case .general:   "General"
        }
    }

    var icon: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .scroll:    "arrow.up.arrow.down"
        case .keys:      "keyboard"
        case .general:   "gearshape"
        }
    }
}
