//
//  SnippetRepository.swift
//  Perch
//

import Foundation

final class SnippetRepository {
    private let defaults = UserDefaults.standard

    /// First run (key never written) seeds the starter snippets — they teach abbreviations and
    /// placeholders by example, and are normal snippets the user edits or deletes. "Clear All"
    /// saves an empty array, so the key exists and nothing ever re-seeds.
    func load() -> [Snippet] {
        guard let data = defaults.data(forKey: Keys.Defaults.snippets) else {
            save(Self.starters)
            return Self.starters
        }
        return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
    }

    static let starters: [Snippet] = [
        Snippet(name: "Meeting notes (try typing ;meet; anywhere)",
                text: "Meeting notes — {date}\nAttendees: {cursor}",
                abbreviation: "meet"),
        Snippet(name: "Signature (edit me — put your own name)",
                text: "Best regards,\nYour Name",
                abbreviation: "sig"),
        Snippet(name: "Quote clipboard (copies become a quote)",
                text: "> {clipboard}",
                abbreviation: "q"),
        // The showcase: every placeholder in one snippet. Copy your raw notes, type ;sum;
        // → a formatted summary with the copied text inside and the caret on Next steps.
        Snippet(name: "Meeting summary (copy notes first, then ;sum;)",
                text: "Summary — {date} at {time}\n\nKey points:\n{clipboard}\n\nNext steps: {cursor}",
                abbreviation: "sum"),
    ]

    func save(_ snippets: [Snippet]) {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        defaults.set(data, forKey: Keys.Defaults.snippets)
    }
}
