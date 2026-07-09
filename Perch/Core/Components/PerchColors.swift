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

    /// "Something needs your attention / action" — permission gates, warnings. Kept separate
    /// from `secondaryAccent` so re-theming Mouse Shift never changes what a warning looks like.
    static let warning = Color.orange

    /// "This deletes data / can't be undone" — destructive confirm buttons.
    static let destructive = Color.red
}
