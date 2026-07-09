//
//  ClipboardIntroSheet.swift
//  Perch
//
//  In-app clipboard intro (the ⓘ button in the Clipboard tab). Wraps the shared
//  ClipboardDemoStage in the app's standard IntroSheet frame so it matches every other
//  module's intro — the demo plays calmly and the caption narrates each feature.
//

import SwiftUI

struct ClipboardIntroSheet: View {
    @State private var caption = "Watch — the whole thing runs from the keyboard."

    var body: some View {
        IntroSheet(title: "How the clipboard works",
                   subtitle: "Everything you copy, one shortcut away — fully keyboard-driven.",
                   caption: caption,
                   tip: "Try it now: press \u{2318}\u{21E7}V in any app.") {
            ClipboardDemoStage(caption: $caption)
        }
    }
}
