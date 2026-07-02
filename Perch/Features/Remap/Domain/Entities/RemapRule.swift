//
//  RemapRule.swift
//  Perch
//
//  Ctrl+keyChar → Cmd+keyChar, unless the frontmost app is excluded.
//

import Foundation

struct RemapRule: Identifiable, Codable, Equatable {
    let id: UUID
    var keyChar: String              // "c","v","x","a","z","p","l"
    var isEnabled: Bool
    var excludedBundleIDs: [String]

    init(id: UUID = UUID(),
         keyChar: String,
         isEnabled: Bool = true,
         excludedBundleIDs: [String] = AppConfig.defaultRemapExcludedBundleIDs) {
        self.id = id
        self.keyChar = keyChar.lowercased()
        self.isEnabled = isEnabled
        self.excludedBundleIDs = excludedBundleIDs
    }

    /// The default set seeded on first launch (brief: C/V/X/A/Z, plus P/L the user uses).
    static let defaults: [RemapRule] = ["c", "v", "x", "a", "z", "p", "l"].map { RemapRule(keyChar: $0) }
}
