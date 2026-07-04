//
//  MouseGesture.swift
//  Perch
//
//  A gesture button: hold it and move the mouse in a direction to fire that direction's
//  action. One action per direction (explicit fields keep it clean to persist).
//

import Foundation

struct MouseGesture: Identifiable, Codable, Equatable {
    let id: UUID
    var button: Int
    var up: Action
    var down: Action
    var left: Action
    var right: Action

    init(id: UUID = UUID(), button: Int,
         up: Action = .disabled, down: Action = .disabled,
         left: Action = .disabled, right: Action = .disabled) {
        self.id = id
        self.button = button
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    func action(for direction: GestureDirection) -> Action {
        switch direction {
        case .up:    return up
        case .down:  return down
        case .left:  return left
        case .right: return right
        }
    }

    mutating func set(_ action: Action, for direction: GestureDirection) {
        switch direction {
        case .up:    up = action
        case .down:  down = action
        case .left:  left = action
        case .right: right = action
        }
    }
}
