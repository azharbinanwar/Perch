//
//  GestureDirection.swift
//  Perch
//
//  The four directions a hold-and-move gesture can go.
//

import Foundation

enum GestureDirection: String, Codable, CaseIterable, Identifiable {
    case up, down, left, right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up:    return "Up"
        case .down:  return "Down"
        case .left:  return "Left"
        case .right: return "Right"
        }
    }

    var icon: String {
        switch self {
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        case .left:  return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}
