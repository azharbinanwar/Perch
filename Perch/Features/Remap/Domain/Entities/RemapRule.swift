//
//  RemapRule.swift
//  Perch
//
//  A general key remap: input combo → output combo, unless the frontmost app is excluded.
//

import CoreGraphics
import Foundation

struct RemapRule: Identifiable, Codable, Equatable {
    let id: UUID
    var input: KeyCombo
    var output: KeyCombo
    var isEnabled: Bool
    var excludedBundleIDs: [String]

    init(id: UUID = UUID(),
         input: KeyCombo,
         output: KeyCombo,
         isEnabled: Bool = true,
         excludedBundleIDs: [String] = AppConfig.defaultRemapExcludedBundleIDs) {
        self.id = id
        self.input = input
        self.output = output
        self.isEnabled = isEnabled
        self.excludedBundleIDs = excludedBundleIDs
    }

    /// Practical Ctrl→Cmd set seeded on first launch (C/V/X/A/Z, plus P/L).
    static let defaults: [RemapRule] = [8, 9, 7, 0, 6, 35, 37].map { code in
        RemapRule(input: KeyCombo(keyCode: code, modifiers: CGEventFlags.maskControl.rawValue),
                  output: KeyCombo(keyCode: code, modifiers: CGEventFlags.maskCommand.rawValue))
    }
}
