//
//  RootWindowView.swift
//  Perch
//
//  The main window's root: shows the first-run onboarding until it's completed, then the hub.
//

import SwiftUI

struct RootWindowView: View {
    @AppStorage("perch.onboarded") private var onboarded = false

    var body: some View {
        if onboarded {
            MainWindowView()
        } else {
            OnboardingView { onboarded = true }
        }
    }
}
