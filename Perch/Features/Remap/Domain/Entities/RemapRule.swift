//
//  RemapRule.swift
//  Perch
//
//  A key remap: press `input` → do `output`. The output is an Action, so it can be a
//  custom keystroke (⌃C → ⌘C) *or* any catalogue action (Mission Control, Open App…).
//  Per-app profiles decide where a rule applies; there's no hard exclude and no timing.
//

import Foundation

struct RemapRule: Identifiable, Codable, Equatable {
    let id: UUID
    var input: KeyCombo
    var output: Action
    var isEnabled: Bool

    init(id: UUID = UUID(), input: KeyCombo, output: Action, isEnabled: Bool = true) {
        self.id = id
        self.input = input
        self.output = output
        self.isEnabled = isEnabled
    }

    /// No rules seeded — the user adds their own.
    static let defaults: [RemapRule] = []

    enum CodingKeys: String, CodingKey { case id, input, output, isEnabled }

    // Lenient decode: older rules stored `output` as a raw KeyCombo — wrap it as a custom keystroke.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        input = try c.decode(KeyCombo.self, forKey: .input)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        if let action = try? c.decode(Action.self, forKey: .output) {
            output = action
        } else if let combo = try? c.decode(KeyCombo.self, forKey: .output) {
            output = Action(kind: .customKeystroke, keyCode: combo.keyCode, modifiers: combo.modifiers)
        } else {
            output = .disabled
        }
    }
}
