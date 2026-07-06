//
//  PerchColors.swift
//  Perch
//
//  Theme roles, named once (Material-style). `accentColor` is the primary; this file
//  adds the rest. Changing a role's color later is a one-line edit here, not a hunt.
//

import SwiftUI

extension Color {
    /// The second brand color — highlights that must stand apart from the accent
    /// (currently Mouse Shift's hold keys, tags, and combo highlights).
    static let secondaryAccent = Color.orange
}
