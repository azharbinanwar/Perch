//
//  WelcomeShowcase.swift
//  Perch
//
//  The onboarding welcome stage: each feature performs its REAL moment in miniature —
//  the clipboard popup pops and pastes, the snippet types itself, the actual mouse
//  diagram fires a shift combo, keycaps run a hyper shortcut. One at a time, on a loop.
//

import SwiftUI

struct WelcomeShowcase: View {

    private enum Feature: Int, CaseIterable {
        case clipboard, snippets, mouse, keys
        var icon: String {
            switch self {
            case .clipboard: "doc.on.clipboard"
            case .snippets:  "text.quote"
            case .mouse:     "computermouse"
            case .keys:      "keyboard"
            }
        }
        var name: String {
            switch self {
            case .clipboard: "Clipboard"
            case .snippets:  "Snippets"
            case .mouse:     "Mouse"
            case .keys:      "Keys"
            }
        }
        var line: String {
            switch self {
            case .clipboard: "Everything you copy, one shortcut away — search, pin, paste."
            case .snippets:  "Type a short code anywhere — it becomes your saved text."
            case .mouse:     "Hold one button, click another — every button gets a job. Per app."
            case .keys:      "Caps Lock becomes a super key — a whole shortcut layer. Per app."
            }
        }
    }

    @State private var feature: Feature = .clipboard

    // Clipboard scene
    @State private var clipVisible = false
    @State private var clipSelected = 0
    @State private var clipPasted = false

    // Snippets scene
    @State private var typed = ""
    @State private var snippetExpanded = false

    // Mouse scene
    @State private var mouseHold: Set<String> = []
    @State private var mouseFlash = ""
    @State private var mouseAction = ""

    // Keys scene
    @State private var capsLit = false
    @State private var letterLit = false
    @State private var keysAction = ""

    var body: some View {
        VStack(spacing: 14) {
            // Feature dots — which of the four is on stage.
            HStack(spacing: 18) {
                ForEach(Feature.allCases, id: \.rawValue) { f in
                    VStack(spacing: 4) {
                        Image(systemName: f.icon)
                            .font(.system(size: f == feature ? 17 : 14))
                            .foregroundStyle(f == feature ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                        Text(f.name)
                            .font(.system(size: 9.5, weight: f == feature ? .semibold : .regular))
                            .foregroundStyle(f == feature ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                    }
                }
            }
            .animation(.spring(duration: 0.35), value: feature)

            // The stage — fixed height so scene swaps never move the layout.
            ZStack {
                switch feature {
                case .clipboard: clipboardScene
                case .snippets:  snippetScene
                case .mouse:     mouseScene
                case .keys:      keysScene
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
            .id(feature)

            Text(feature.line)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .task { await runLoop() }
    }

    // MARK: - Clipboard: the mini popup opens, selection moves, Enter pastes

    private static let clipItems = ["Invoice #2041", "hello@perch.app", "Meeting notes"]

    private var clipboardScene: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.secondary)
                Text("Type to search…").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Text("⌘⇧V").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            Divider()
            VStack(spacing: 2) {
                ForEach(Array(Self.clipItems.enumerated()), id: \.offset) { i, text in
                    HStack(spacing: 7) {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 9))
                            .foregroundStyle(i == clipSelected ? Color.white : .secondary)
                        Text(text).font(.system(size: 10.5))
                            .foregroundStyle(i == clipSelected ? Color.white : .primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(i == clipSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear),
                                in: RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(6)
            if clipPasted {
                Divider()
                Label("Pasted into your app", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 6)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(width: 250)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
        .opacity(clipVisible ? 1 : 0)
        .scaleEffect(clipVisible ? 1 : 0.9)
        .animation(.spring(duration: 0.3), value: clipVisible)
        .animation(.easeOut(duration: 0.16), value: clipSelected)
        .animation(.spring(duration: 0.3), value: clipPasted)
    }

    // MARK: - Snippets: the abbreviation types itself, then morphs

    private var snippetScene: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(typed)
                .font(.system(size: 14, design: snippetExpanded ? .default : .monospaced))
                .foregroundStyle(snippetExpanded ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
            Rectangle().fill(Color.accentColor).frame(width: 2, height: 16).padding(.top, 1)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 300, height: 96, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.35)))
        .animation(.easeOut(duration: 0.18), value: snippetExpanded)
    }

    // MARK: - Mouse: the real diagram runs a shift combo

    private var mouseScene: some View {
        HStack(spacing: 18) {
            MouseDiagramView(selected: $mouseFlash,
                             isMapped: { _ in false },
                             isActive: { ["left", "right", "middle", "top", "back", "fwd"].contains($0) },
                             holdIDs: mouseHold,
                             onSelect: { _ in })
                .scaleEffect(0.48)
                .frame(width: 125, height: 160)
            ZStack {
                if !mouseAction.isEmpty {
                    Label(mouseAction, systemImage: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondaryAccent)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.secondaryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(width: 150)
            .animation(.spring(duration: 0.35), value: mouseAction)
        }
    }

    // MARK: - Keys: keycaps run a hyper shortcut

    private var keysScene: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                keycap("caps lock", width: 96, lit: capsLit)
                Image(systemName: "plus").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                keycap("W", width: 44, lit: letterLit)
            }
            ZStack {
                if !keysAction.isEmpty {
                    Label(keysAction, systemImage: "message.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(width: 160)
            .animation(.spring(duration: 0.35), value: keysAction)
        }
    }

    private func keycap(_ label: String, width: CGFloat, lit: Bool) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(lit ? Color.white : Color.primary)
            .frame(width: width, height: 40)
            .background(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(lit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: lit ? 1.5 : 1))
            .scaleEffect(lit ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: lit)
    }

    // MARK: - The loop: each feature performs once, then the stage moves on

    private func runLoop() async {
        do {
            while true {
                switch feature {
                case .clipboard:
                    clipVisible = false; clipSelected = 0; clipPasted = false
                    try await Task.sleep(for: .milliseconds(500))
                    clipVisible = true                              // ⌘⇧V — it pops open
                    try await Task.sleep(for: .milliseconds(900))
                    clipSelected = 1                                // ↓
                    try await Task.sleep(for: .milliseconds(500))
                    clipSelected = 2                                // ↓
                    try await Task.sleep(for: .milliseconds(600))
                    clipPasted = true                               // ⏎
                    try await Task.sleep(for: .milliseconds(1600))

                case .snippets:
                    typed = ""; snippetExpanded = false
                    try await Task.sleep(for: .milliseconds(400))
                    for ch in ";meet;" {                            // it types itself
                        typed.append(ch)
                        try await Task.sleep(for: .milliseconds(130))
                    }
                    try await Task.sleep(for: .milliseconds(450))
                    snippetExpanded = true                          // …and becomes the text
                    typed = "Meeting notes — \(SnippetPlaceholders.example("yyyy-MM-dd"))\nAttendees: "
                    try await Task.sleep(for: .milliseconds(2100))

                case .mouse:
                    mouseHold = []; mouseFlash = ""; mouseAction = ""
                    try await Task.sleep(for: .milliseconds(500))
                    mouseHold = ["back"]                            // finger down — amber HOLD
                    try await Task.sleep(for: .milliseconds(800))
                    mouseFlash = "left"                             // the click
                    try await Task.sleep(for: .milliseconds(300))
                    mouseAction = "Spotlight"                       // ✨
                    try await Task.sleep(for: .milliseconds(1800))

                case .keys:
                    capsLit = false; letterLit = false; keysAction = ""
                    try await Task.sleep(for: .milliseconds(500))
                    capsLit = true                                  // caps held
                    try await Task.sleep(for: .milliseconds(700))
                    letterLit = true                                // W taps
                    try await Task.sleep(for: .milliseconds(250))
                    keysAction = "Open WhatsApp"                    // ✨
                    try await Task.sleep(for: .milliseconds(300))
                    letterLit = false
                    try await Task.sleep(for: .milliseconds(1500))
                }

                withAnimation(.easeInOut(duration: 0.25)) {
                    feature = Feature(rawValue: (feature.rawValue + 1) % Feature.allCases.count) ?? .clipboard
                }
            }
        } catch {}   // view left the screen → task cancelled
    }
}
