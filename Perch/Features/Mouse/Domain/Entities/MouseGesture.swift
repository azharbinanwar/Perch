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
    var up: MouseAction
    var down: MouseAction
    var left: MouseAction
    var right: MouseAction

    init(id: UUID = UUID(), button: Int,
         up: MouseAction = .disabled, down: MouseAction = .disabled,
         left: MouseAction = .disabled, right: MouseAction = .disabled) {
        self.id = id
        self.button = button
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    func action(for direction: GestureDirection) -> MouseAction {
        switch direction {
        case .up:    return up
        case .down:  return down
        case .left:  return left
        case .right: return right
        }
    }

    mutating func set(_ action: MouseAction, for direction: GestureDirection) {
        switch direction {
        case .up:    up = action
        case .down:  down = action
        case .left:  left = action
        case .right: right = action
        }
    }
}
