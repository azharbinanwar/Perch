//
//  ClipboardCategory.swift
//  Perch
//
//  The single switcher for the popup: All + one per content type + Snippets. Empty content
//  types are hidden by the model, so the bar grows with what you actually have.
//

import Foundation

enum ClipboardCategory: String, CaseIterable, Identifiable {
    case all, text, images, files, links, snippets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      return "All"
        case .text:     return "Text"
        case .images:   return "Images"
        case .files:    return "Files"
        case .links:    return "Links"
        case .snippets: return "Snippets"
        }
    }

    var isSnippets: Bool { self == .snippets }

    /// The content-type filter. `all` matches everything; `snippets` isn't a clipboard filter.
    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:    return true
        case .text:   return item.content == .text
        case .images: return item.content == .image
        case .files:  return item.content == .files
        case .links:
            guard item.content == .text else { return false }
            switch ClipboardKind.detect(item.text) {
            case .link, .email: return true
            default:            return false
            }
        case .snippets: return false
        }
    }

    /// The content-type categories, in bar order (excludes All / Snippets).
    static let contentTypes: [ClipboardCategory] = [.text, .images, .files, .links]
}
