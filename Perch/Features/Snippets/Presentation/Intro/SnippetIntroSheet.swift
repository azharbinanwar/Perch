//
//  SnippetIntroSheet.swift
//  Perch
//
//  In-app snippets intro (the ⓘ button). Wraps the shared SnippetDemoStage in the app's
//  standard IntroSheet frame so it matches every other module's intro.
//

import SwiftUI

struct SnippetIntroSheet: View {
    @State private var caption = "Watch — this is what happens as you type."

    var body: some View {
        IntroSheet(title: "How snippets work",
                   subtitle: "Watch — this is what happens as you type.",
                   caption: caption,
                   tip: "Try it yourself: the starter snippets are already in your list.") {
            SnippetDemoStage(caption: $caption)
        }
    }
}
