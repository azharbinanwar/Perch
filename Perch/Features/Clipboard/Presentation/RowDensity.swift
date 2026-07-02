//
//  RowDensity.swift
//  Perch
//
//  How roomy each clipboard row is. User-selectable in the Clipboard tab.
//

import Foundation

enum RowDensity: String, CaseIterable, Codable {
    case compact, regular, large

    var title: String {
        switch self {
        case .compact: "Compact"
        case .regular: "Regular"
        case .large:   "Large"
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: 16
        case .regular: 22
        case .large:   30
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .compact: 12.5
        case .regular: 13
        case .large:   14
        }
    }

    var lineLimit: Int {
        switch self {
        case .compact, .regular: 1
        case .large:             2
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: 5
        case .regular: 8
        case .large:   11
        }
    }

    /// Compact hides the timestamp to stay dense.
    var showsTime: Bool { self != .compact }
}
