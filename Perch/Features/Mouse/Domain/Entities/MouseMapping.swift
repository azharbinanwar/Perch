//
//  MouseMapping.swift
//  Perch
//
//  One button binding. A button can carry up to three actions by how it's pressed:
//  single click, double click, and hold. (Keystroke triggers use only `single`.)
//

import Foundation

struct MouseMapping: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: MouseTrigger
    var action: Action        // single click
    var doubleAction: Action
    var holdAction: Action

    init(id: UUID = UUID(), trigger: MouseTrigger,
         action: Action = .disabled,
         doubleAction: Action = .disabled,
         holdAction: Action = .disabled) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.doubleAction = doubleAction
        self.holdAction = holdAction
    }

    // Lenient decode so mappings saved before variants existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        trigger = try c.decode(MouseTrigger.self, forKey: .trigger)
        action = try c.decode(Action.self, forKey: .action)
        doubleAction = try c.decodeIfPresent(Action.self, forKey: .doubleAction) ?? .disabled
        holdAction = try c.decodeIfPresent(Action.self, forKey: .holdAction) ?? .disabled
    }

    func action(for phase: ClickPhase) -> Action {
        switch phase {
        case .single: return action
        case .double: return doubleAction
        case .hold:   return holdAction
        }
    }

    mutating func setAction(_ newAction: Action, for phase: ClickPhase) {
        switch phase {
        case .single: action = newAction
        case .double: doubleAction = newAction
        case .hold:   holdAction = newAction
        }
    }

    /// True when double or hold is configured — the engine only needs the timing machine then.
    var hasVariants: Bool {
        doubleAction.kind != .disabled || holdAction.kind != .disabled
    }
}
