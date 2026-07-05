//
//  Snippet.swift
//  Perch
//
//  A user-created, permanent reusable clip (name + text). Separate from copy history.
//

import Foundation

struct Snippet: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var text: String
    var abbreviation: String?   // type prefix+this anywhere → expands to `text` (nil = popup-only)

    init(id: UUID = UUID(), name: String, text: String, abbreviation: String? = nil) {
        self.id = id
        self.name = name
        self.text = text
        self.abbreviation = abbreviation
    }
}
