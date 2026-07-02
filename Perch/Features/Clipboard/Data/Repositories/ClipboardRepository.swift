//
//  ClipboardRepository.swift
//  Perch
//
//  Persists clipboard history as JSON in UserDefaults. Sync, in-memory sized —
//  no async/failure path, so no AsyncState here.
//  ponytail: UserDefaults JSON is plenty for <=50 text items; move to a file/DB only if history grows huge.
//

import Foundation

final class ClipboardRepository {
    private let defaults = UserDefaults.standard

    func load() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: Keys.Defaults.clipboardHistory),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }
        return items
    }

    func save(_ items: [ClipboardItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Keys.Defaults.clipboardHistory)
    }
}
