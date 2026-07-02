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

    init(id: UUID = UUID(), name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}
