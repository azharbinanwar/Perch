//
//  ClipboardAction.swift
//  Perch
//
//  Context-aware actions on a clipboard item. One source of truth: the row menu, the key
//  tap, and the shortcuts cheat-sheet all read title/icon/keys/`applies(to:)` from here.
//

import Foundation

enum ClipboardAction: String, CaseIterable, Identifiable {
    case openLink
    case revealInFinder
    case saveImage
    case copyPlain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openLink:       return "Open Link"
        case .revealInFinder: return "Reveal in Finder"
        case .saveImage:      return "Save to Downloads"
        case .copyPlain:      return "Copy as Plain Text"
        }
    }

    var icon: String {
        switch self {
        case .openLink:       return "safari"
        case .revealInFinder: return "folder"
        case .saveImage:      return "square.and.arrow.down"
        case .copyPlain:      return "doc.plaintext"
        }
    }

    /// Keyboard shortcut, or "" for menu-only actions.
    var keys: String {
        switch self {
        case .openLink:       return "⌘O"
        case .revealInFinder: return "⌘R"
        case .saveImage:      return "⌘S"
        case .copyPlain:      return ""
        }
    }

    func applies(to item: ClipboardItem) -> Bool {
        switch self {
        case .openLink:
            guard item.content == .text else { return false }
            switch ClipboardKind.detect(item.text) {
            case .link, .email: return true
            default:            return false
            }
        case .revealInFinder: return item.content == .files
        case .saveImage:      return item.content == .image
        case .copyPlain:      return item.content == .text
        }
    }

    /// The actions available for an item, in menu order.
    static func available(for item: ClipboardItem) -> [ClipboardAction] {
        allCases.filter { $0.applies(to: item) }
    }
}
