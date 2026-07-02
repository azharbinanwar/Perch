//
//  PopupShortcut.swift
//  Perch
//
//  Single source of truth for the ⌘⇧V popup shortcuts. The cheat-sheet renders all of
//  them; the footer renders the small subset that has a `footerLabel`. Edit here once.
//

struct PopupShortcut: Identifiable {
    let keys: String
    let label: String          // full description (cheat-sheet)
    let footerLabel: String?   // short label for the footer; nil = not shown there
    var id: String { keys }
}

enum PopupShortcuts {
    static let all: [PopupShortcut] = [
        .init(keys: "↑ ↓",     label: "Move (wraps)",       footerLabel: "Move"),
        .init(keys: "⇥",       label: "Clipboard / Snippets", footerLabel: "Switch"),
        .init(keys: "⌘↑ / ⌘↓", label: "Top / Bottom",       footerLabel: nil),
        .init(keys: "Space",   label: "Preview (empty search)", footerLabel: nil),
        .init(keys: "⌘Y",      label: "Preview (always)",   footerLabel: nil),
        .init(keys: "⏎",       label: "Paste & close",      footerLabel: "Paste"),
        .init(keys: "⌘⏎",      label: "Paste & keep open",  footerLabel: nil),
        .init(keys: "⌘⇧⏎",     label: "Paste plain (no formatting)", footerLabel: nil),
        .init(keys: "⌘1–9",    label: "Quick paste",        footerLabel: nil),
        .init(keys: "⌘⌫",      label: "Delete item",        footerLabel: nil),
        .init(keys: "⌘C",      label: "Copy (no paste)",    footerLabel: nil),
        .init(keys: "⌘P",      label: "Pin / Unpin",        footerLabel: nil),
        .init(keys: "⌘K",      label: "Clear all",          footerLabel: nil),
        .init(keys: "⌫",       label: "Delete search char", footerLabel: nil),
        .init(keys: "⌘/",      label: "All shortcuts",      footerLabel: "Shortcuts"),
        .init(keys: "esc",     label: "Close",              footerLabel: "Close"),
    ]

    static var footer: [PopupShortcut] { all.filter { $0.footerLabel != nil } }
}
