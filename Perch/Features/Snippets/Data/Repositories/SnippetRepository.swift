//
//  SnippetRepository.swift
//  Perch
//

import Foundation

final class SnippetRepository {
    private let defaults = UserDefaults.standard

    func load() -> [Snippet] {
        guard let data = defaults.data(forKey: Keys.Defaults.snippets),
              let snippets = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return []
        }
        return snippets
    }

    func save(_ snippets: [Snippet]) {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        defaults.set(data, forKey: Keys.Defaults.snippets)
    }
}
