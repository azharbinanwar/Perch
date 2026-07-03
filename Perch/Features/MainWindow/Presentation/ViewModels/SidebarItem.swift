//
//  SidebarItem.swift
//  Perch
//

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
        case .clipboard: "doc.on.clipboard"
        case .snippets:  "note.text"
        case .mouse:     "computermouse"
        case .keys:      "keyboard"
        case .general:   "gearshape"
        }
    }
}
