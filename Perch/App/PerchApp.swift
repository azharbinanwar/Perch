//
//  PerchApp.swift
//  Perch
//

import SwiftUI

@main
struct PerchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Perch", image: "perch") {
            MenuContentView(app: appDelegate)
                .injecting(appDelegate)
        }
        .menuBarExtraStyle(.window)

        Window("Perch", id: "main") {
            RootWindowView().injecting(appDelegate)
        }
        .windowResizability(.contentSize)
    }
}

private extension View {
    /// Inject every ViewModel the app's views need.
    func injecting(_ delegate: AppDelegate) -> some View {
        self.environment(delegate.clipboardVM)
            .environment(delegate.scrollVM)
            .environment(delegate.mouseVM)
            .environment(delegate.pointerVM)
            .environment(delegate.remapVM)
            .environment(delegate.settingsVM)
            .environment(delegate.snippetVM)
    }
}
