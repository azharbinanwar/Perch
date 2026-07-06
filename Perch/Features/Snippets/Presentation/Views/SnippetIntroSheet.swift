//
//  SnippetIntroSheet.swift
//  Perch
//
//  A live "watch it happen" intro: a fake text field types an abbreviation by itself,
//  then it visibly becomes the expanded snippet — the trick explained without words.
//  Loops through the starter snippets until dismissed. Uses the shared IntroSheet frame.
//

import SwiftUI

struct SnippetIntroSheet: View {

    private struct Demo {
        let caption: String
        let token: String       // what "the user" types
        let expanded: String    // what it becomes
    }

    // The demos mirror the starter snippets 1:1 — what plays here is what's in the list.
    private var demos: [Demo] {
        let today = SnippetPlaceholders.example("yyyy-MM-dd")
        let now = SnippetPlaceholders.example("HH:mm")
        return [
            Demo(caption: "Type an abbreviation anywhere — it becomes the full text.",
                 token: ";meet;",
                 expanded: "Meeting notes — \(today)\nAttendees: "),
            Demo(caption: "{clipboard} drops in whatever you last copied.",
                 token: ";q;",
                 expanded: "> the text you just copied"),
            Demo(caption: "Any text you reuse — one shortcut away.",
                 token: ";sig;",
                 expanded: "Best regards,\nYour Name"),
            Demo(caption: "All together: copy your notes, type ;sum; — date, time, clipboard and the cursor land in place.",
                 token: ";sum;",
                 expanded: "Summary — \(today) at \(now)\n\nKey points:\nthe notes you copied earlier\n\nNext steps: "),
        ]
    }

    @State private var displayed = ""
    @State private var caption = ""
    @State private var expanded = false      // false = typing the token, true = showing the result
    @State private var caretVisible = true

    var body: some View {
        IntroSheet(title: "How snippets work",
                   subtitle: "Watch — this is what happens as you type.",
                   caption: caption,
                   tip: "Try it yourself: the starter snippets are already in your list.") {
            // The fake text field where the demo types.
            HStack(alignment: .top, spacing: 0) {
                Text(displayed)
                    .font(.system(size: 15, design: expanded ? .default : .monospaced))
                    .foregroundStyle(expanded ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 18)
                    .opacity(caretVisible ? 1 : 0)
                    .padding(.top, expanded && displayed.contains("\n") ? 20 : 1)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.35)))
            .animation(.easeOut(duration: 0.18), value: expanded)
        }
        .task { await runLoop() }
        .task { await blinkCaret() }
    }

    /// Endless demo loop: type the token, pause, morph to the result, linger, next.
    private func runLoop() async {
        do {
            while true {
                for demo in demos {
                    caption = demo.caption
                    expanded = false
                    displayed = ""
                    try await Task.sleep(for: .milliseconds(500))
                    for ch in demo.token {
                        displayed.append(ch)
                        try await Task.sleep(for: .milliseconds(140))
                    }
                    try await Task.sleep(for: .milliseconds(600))
                    expanded = true
                    displayed = demo.expanded
                    // Longer results linger longer so they can actually be read.
                    try await Task.sleep(for: .milliseconds(2200 + demo.expanded.count * 15))
                }
            }
        } catch {}   // sheet dismissed → task cancelled
    }

    private func blinkCaret() async {
        do {
            while true {
                try await Task.sleep(for: .milliseconds(450))
                caretVisible.toggle()
            }
        } catch {}
    }
}
