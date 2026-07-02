//
//  SnippetViewModel.swift
//  Perch
//

import Observation

@Observable
final class SnippetViewModel {
    private(set) var snippets: [Snippet]

    private let repository: SnippetRepository

    init(repository: SnippetRepository = ServiceLocator.shared.resolve(SnippetRepository.self)) {
        self.repository = repository
        self.snippets = repository.load()
    }

    /// Add a new snippet or update an existing one (matched by id).
    func upsert(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }
        repository.save(snippets)
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        repository.save(snippets)
    }
}
