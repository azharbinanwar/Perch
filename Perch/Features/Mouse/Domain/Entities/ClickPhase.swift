//
//  ClickPhase.swift
//  Perch
//
//  The three ways one button can be pressed, each mappable to its own action.
//

import Foundation

enum ClickPhase: String, Codable, CaseIterable, Identifiable {
    case single, double, hold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "Click"
        case .double: return "Double-click"
        case .hold:   return "Hold"
        }
    }

    var icon: String {
        switch self {
        case .single: return "cursorarrow.click"
        case .double: return "cursorarrow.click.2"
        case .hold:   return "hand.point.up.left"
        }
    }
}
