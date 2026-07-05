//
//  SnippetViewModel.swift
//  Perch
//

import Foundation
import Observation

@Observable
final class SnippetViewModel {
    private(set) var snippets: [Snippet]

    // Text expansion (type ;abbr anywhere → the snippet text).
    private(set) var expansionEnabled: Bool
    private(set) var expansionPrefix: ExpansionPrefix

    private let repository: SnippetRepository
    private let expander: SnippetExpander
    private let defaults = UserDefaults.standard

    init(repository: SnippetRepository = ServiceLocator.shared.resolve(SnippetRepository.self),
         expander: SnippetExpander = ServiceLocator.shared.resolve(SnippetExpander.self)) {
        self.repository = repository
        self.expander = expander
        self.snippets = repository.load()
        self.expansionEnabled = defaults.bool(forKey: Keys.Defaults.snippetsExpansionOn)
        self.expansionPrefix = ExpansionPrefix(rawValue: defaults.string(forKey: Keys.Defaults.snippetsExpansionPrefix) ?? "") ?? .default
    }

    /// Add a new snippet or update an existing one (matched by id).
    /// Re-read from storage (used after Import).
    func reload() {
        snippets = repository.load()
        expansionEnabled = defaults.bool(forKey: Keys.Defaults.snippetsExpansionOn)
        expansionPrefix = ExpansionPrefix(rawValue: defaults.string(forKey: Keys.Defaults.snippetsExpansionPrefix) ?? "") ?? .default
        applyExpansion()
    }

    func upsert(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }
        repository.save(snippets)
        applyExpansion()
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        repository.save(snippets)
        applyExpansion()
    }

    func clearAll() {
        snippets.removeAll()
        repository.save(snippets)
        applyExpansion()
    }

    // MARK: - Text expansion

    /// Abbreviations already in use (for the editor's uniqueness check).
    func takenAbbreviations(excluding id: UUID?) -> Set<String> {
        Set(snippets.filter { $0.id != id }.compactMap(\.abbreviation))
    }

    func setExpansionEnabled(_ on: Bool) {
        expansionEnabled = on
        defaults.set(on, forKey: Keys.Defaults.snippetsExpansionOn)
        applyExpansion()
    }

    func setExpansionPrefix(_ prefix: ExpansionPrefix) {
        expansionPrefix = prefix
        defaults.set(prefix.rawValue, forKey: Keys.Defaults.snippetsExpansionPrefix)
        applyExpansion()
    }

    /// Push snippets + settings into the engine. Called at launch and after every change.
    func applyExpansion() {
        expander.prefix = expansionPrefix.rawValue
        expander.abbreviations = Dictionary(
            snippets.compactMap { s in s.abbreviation.flatMap { a in a.isEmpty ? nil : (a, s.text) } },
            uniquingKeysWith: { first, _ in first })
        expander.isActive = expansionEnabled && !expander.abbreviations.isEmpty
        if expander.isActive { expander.start() }
    }
}
