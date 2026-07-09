//
//  SnippetDemoStage.swift
//  Perch
//
//  The ONE snippets demo animation: a fake text field types an abbreviation by itself, then it
//  visibly becomes the expanded snippet. Reused by the gate and the in-app intro sheet.
//  Publishes the running caption via a binding. (Extracted from the old SnippetIntroSheet.)
//

import SwiftUI

struct SnippetDemoStage: View {
    @Binding var caption: String
    var showDots = false

    private struct Demo {
        let caption: String
        let token: String       // what "the user" types
        let expanded: String    // what it becomes
    }

    private var demos: [Demo] {
        let today = SnippetPlaceholders.example("yyyy-MM-dd")
        let now = SnippetPlaceholders.example("HH:mm")
        return [
            Demo(caption: "Type an abbreviation anywhere — it becomes the full text.",
                 token: ";meet;", expanded: "Meeting notes — \(today)\nAttendees: "),
            Demo(caption: "{clipboard} drops in whatever you last copied.",
                 token: ";q;", expanded: "> the text you just copied"),
            Demo(caption: "Any text you reuse — one shortcut away.",
                 token: ";sig;", expanded: "Best regards,\nYour Name"),
            Demo(caption: "All together: type ;sum; — date, time, clipboard and the cursor land in place.",
                 token: ";sum;", expanded: "Summary — \(today) at \(now)\n\nKey points:\nthe notes you copied earlier\n\nNext steps: "),
        ]
    }

    @State private var sceneIndex = 0
    @State private var displayed = ""
    @State private var expanded = false
    @State private var caretVisible = true
    @State private var playTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            field
            if showDots { dots }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { present(0) }
        .onDisappear { playTask?.cancel() }
        .task { await blinkCaret() }
    }

    private var field: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(displayed)
                .font(.system(size: 13, design: expanded ? .default : .monospaced))
                .foregroundStyle(expanded ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2, height: 18)
                .opacity(caretVisible ? 1 : 0)
                .padding(.top, expanded && displayed.contains("\n") ? 20 : 1)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 300, height: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.35)))
        .animation(.easeOut(duration: 0.18), value: expanded)
    }

    // MARK: - Dots + nav

    private var dots: some View {
        HStack(spacing: 12) {
            navButton("chevron.left") { present(sceneIndex - 1) }
            HStack(spacing: 6) {
                ForEach(demos.indices, id: \.self) { i in
                    Button { present(i) } label: {
                        Circle()
                            .fill(i == sceneIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: i == sceneIndex ? 7 : 5, height: i == sceneIndex ? 7 : 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.easeOut(duration: 0.2), value: sceneIndex)
            navButton("chevron.right") { present(sceneIndex + 1) }
        }
    }

    private func navButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.quaternary.opacity(0.5), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playback

    private func present(_ i: Int) {
        let n = ((i % demos.count) + demos.count) % demos.count
        sceneIndex = n
        playTask?.cancel()
        playTask = Task { await play(demos[n]) }
    }

    private func play(_ d: Demo) async {
        caption = d.caption
        expanded = false
        displayed = ""
        try? await Task.sleep(for: .milliseconds(500))
        for ch in d.token {
            if Task.isCancelled { return }
            displayed.append(ch)
            try? await Task.sleep(for: .milliseconds(140))
        }
        try? await Task.sleep(for: .milliseconds(600))
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.18)) { expanded = true; displayed = d.expanded }
        try? await Task.sleep(for: .milliseconds(2400 + d.expanded.count * 15))
        if Task.isCancelled { return }
        present(sceneIndex + 1)   // auto-advance
    }

    private func blinkCaret() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(450))
            caretVisible.toggle()
        }
    }
}
