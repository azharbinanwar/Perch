//
//  PerchApp.swift
//  Perch
//

import SwiftUI

@main
struct PerchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(app: appDelegate)
                .injecting(appDelegate)
        } label: {
            // The label renders the moment the app starts (the dropdown content doesn't),
            // so THIS is where the window-opening handle must be captured — otherwise
            // "Open window at launch" has no way to open the window on a fresh run.
            MenuBarIcon(appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)

        Window("Perch", id: "main") {
            RootWindowView().injecting(appDelegate)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarIcon: View {
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("perch")
            .onAppear { appDelegate.openWindowAction = { openWindow(id: $0) } }
    }
}

private extension View {
    /// Inject every ViewModel the app's views need.
    func injecting(_ delegate: AppDelegate) -> some View {
        self.environment(delegate.clipboardVM)
            .environment(delegate.mouseVM)
            .environment(delegate.remapVM)
            .environment(delegate.settingsVM)
            .environment(delegate.snippetVM)
    }
}
