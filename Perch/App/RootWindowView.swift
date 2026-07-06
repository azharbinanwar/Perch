//
//  RootWindowView.swift
//  Perch
//
//  The main window's root: shows the first-run onboarding until it's completed, then the hub.
//

import SwiftUI

struct RootWindowView: View {
    @AppStorage(Keys.Defaults.onboarded) private var onboarded = false

    /// True forces onboarding on every launch (used while iterating on its design).
    private static let previewOnboarding = false

    var body: some View {
        if onboarded && !Self.previewOnboarding {
            MainWindowView()
        } else {
            OnboardingView { onboarded = true }
        }
    }
}
