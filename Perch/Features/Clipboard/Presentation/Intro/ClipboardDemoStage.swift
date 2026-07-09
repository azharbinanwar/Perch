//
//  ClipboardDemoStage.swift
//  Perch
//
//  The ONE clipboard demo animation, reused everywhere: a combined key chip presses and a
//  mini popup reacts, touring the whole feature set (open · browse · search · categories ·
//  pin · quick-paste · snippets · paste). It publishes the running caption via a binding so
//  the surrounding frame (IntroSheet in-app, or the permission gate) narrates it.
//

import SwiftUI

struct ClipboardDemoStage: View {
    /// The stage writes the current scene's caption here; the wrapper displays it.
    @Binding var caption: String
    /// Faint, clickable progress dots (on for the gate; off inside IntroSheet, which stays calm).
    var showDots = false

    // MARK: - Demo data

    private enum Kind { case text, link, email, image, snippet }
    private struct Item { let kind: Kind; let text: String; let tint: Color }

    private static let pool: [Item] = [
        .init(kind: .text,    text: "Invoice #2041 — attached below", tint: .secondary),
        .init(kind: .email,   text: "hello@perch.app",                tint: .accentColor),
        .init(kind: .link,    text: "https://apple.com",              tint: .accentColor),
        .init(kind: .text,    text: "Meeting notes from Monday",      tint: .secondary),
        .init(kind: .image,   text: "Screenshot 2026-07-07.png",      tint: .accentColor),
        .init(kind: .snippet, text: ";sig → Best regards, Azhar",     tint: .accentColor),
    ]

    private enum Cat: String, CaseIterable { case all = "All", text = "Text", images = "Images", snippets = "Snippets" }

    private struct Scene {
        let caption: String
        let key: String
        let category: Cat
        let visible: [Int]
        let selected: Int
        var search: String = ""
        var pinned: Int? = nil
        var numbers: Bool = false
        var pasted: String? = nil
    }

    private let scenes: [Scene] = [
        .init(caption: "Press ⌘⇧V in any app — your whole clipboard appears, and that app keeps focus.",
              key: "⌘⇧V", category: .all, visible: [0, 1, 2, 3], selected: 0),
        .init(caption: "Arrow keys walk every copy you've made. Hands never leave the keyboard.",
              key: "↓", category: .all, visible: [0, 1, 2, 3], selected: 2),
        .init(caption: "Just start typing — Perch filters instantly. No clicking a search box first.",
              key: "inv", category: .all, visible: [0], selected: 0, search: "inv"),
        .init(caption: "Text, links, images, snippets — jump straight to the category you need.",
              key: "⇥", category: .images, visible: [4], selected: 0),
        .init(caption: "Pin your go-to clips to the top — always a glance away.",
              key: "⌘P", category: .all, visible: [1, 0, 2, 3], selected: 0, pinned: 1),
        .init(caption: "⌘1–9 fires an item instantly — no scrolling, no aiming.",
              key: "⌘2", category: .all, visible: [0, 1, 2, 3], selected: 1, numbers: true,
              pasted: "Pasted “hello@perch.app”"),
        .init(caption: "Snippets expand with {date}, {clipboard} and more — type a trigger, it fills in.",
              key: "⇥", category: .snippets, visible: [5], selected: 0),
        .init(caption: "Enter drops it into the app you came from. Copy once, paste forever.",
              key: "⏎", category: .all, visible: [0, 1, 2, 3], selected: 0,
              pasted: "Pasted into your app"),
    ]

    // MARK: - Live state

    @State private var sceneIndex = 0
    @State private var keyLit = false
    @State private var category: Cat = .all
    @State private var visible: [Int] = [0, 1, 2, 3]
    @State private var selected = 0
    @State private var search = ""
    @State private var pinned: Int? = nil
    @State private var numbers = false
    @State private var pasted = ""
    @State private var popup = false

    @State private var keyTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?

    private var scene: Scene { scenes[sceneIndex] }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 18) {
            keyRow
            popupCard
            if showDots { dots }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { popup = true; present(0) }
        .onDisappear { keyTask?.cancel(); advanceTask?.cancel() }
    }

    private var keyRow: some View {
        Text(scene.key)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(keyLit ? Color.white : .primary)
            .frame(minWidth: 64, minHeight: 40)
            .padding(.horizontal, 12)
            .background(keyLit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(keyLit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: keyLit ? 1.5 : 1))
            .scaleEffect(keyLit ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: keyLit)
            .frame(height: 44)
    }

    // MARK: - Mini popup

    private var popupCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(search.isEmpty ? "Type to search…" : search)
                    .font(.system(size: 11))
                    .foregroundStyle(search.isEmpty ? .tertiary : .primary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)

            HStack(spacing: 4) {
                ForEach(Cat.allCases, id: \.self) { c in
                    Text(c.rawValue)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(category == c ? Color.white : .secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(category == c ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear),
                                    in: Capsule())
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 6)

            Divider()

            VStack(spacing: 2) {
                ForEach(Array(visible.enumerated()), id: \.element) { pos, idx in
                    row(pos: pos, idx: idx)
                }
            }
            .padding(6)
            .animation(.easeOut(duration: 0.22), value: visible)
            .animation(.easeOut(duration: 0.18), value: selected)

            if !pasted.isEmpty {
                Divider()
                Label(pasted, systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 8)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 7)
        .opacity(popup ? 1 : 0)
        .scaleEffect(popup ? 1 : 0.94)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: popup)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: visible)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: pasted)
        .animation(.smooth(duration: 0.3), value: category)
    }

    private func row(pos: Int, idx: Int) -> some View {
        let item = Self.pool[idx]
        let isSel = pos == selected
        return HStack(spacing: 8) {
            if item.kind == .image {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.5)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 18, height: 18)
                    .overlay(Image(systemName: "photo").font(.system(size: 8)).foregroundStyle(.white))
            } else {
                Image(systemName: glyph(item.kind))
                    .font(.system(size: 10))
                    .foregroundStyle(isSel ? Color.white : item.tint)
                    .frame(width: 18)
            }
            Text(item.text)
                .font(.system(size: 10.5))
                .foregroundStyle(isSel ? Color.white : .primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if pinned == idx {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(isSel ? Color.white : Color.accentColor)
                    .transition(.scale.combined(with: .opacity))
            }
            if numbers, pos < 9 {
                Text("⌘\(pos + 1)")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(isSel ? Color.white.opacity(0.9) : .secondary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(isSel ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.quaternary),
                                in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isSel ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear),
                    in: RoundedRectangle(cornerRadius: 6))
    }

    private func glyph(_ k: Kind) -> String {
        switch k {
        case .text:    return "doc.on.clipboard"
        case .link:    return "globe"
        case .email:   return "envelope.fill"
        case .image:   return "photo"
        case .snippet: return "text.quote"
        }
    }

    /// ‹  • • • • •  ›  — auto-plays, but the user can step back/next or jump to a dot.
    private var dots: some View {
        HStack(spacing: 12) {
            navButton("chevron.left") { present(sceneIndex - 1) }
            HStack(spacing: 6) {
                ForEach(scenes.indices, id: \.self) { i in
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

    private func apply(_ s: Scene) {
        category = s.category
        visible = s.visible
        selected = s.selected
        search = s.search
        pinned = s.pinned
        numbers = s.numbers
        pasted = s.pasted ?? ""
    }

    private func present(_ i: Int) {
        let n = ((i % scenes.count) + scenes.count) % scenes.count
        sceneIndex = n
        caption = scenes[n].caption
        keyTask?.cancel()
        keyTask = Task { await playKey(scenes[n]) }
        scheduleAdvance()
    }

    /// One smooth press → the popup reacts (single combined chip, like the app's other intros).
    private func playKey(_ s: Scene) async {
        if !pasted.isEmpty { withAnimation(.easeOut(duration: 0.2)) { pasted = "" } }
        try? await Task.sleep(for: .milliseconds(500))
        if Task.isCancelled { return }
        keyLit = true
        try? await Task.sleep(for: .milliseconds(260))
        if Task.isCancelled { return }
        keyLit = false
        try? await Task.sleep(for: .milliseconds(120))
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { apply(s) }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task {
            let dwell = scene.pasted != nil ? 4.2 : 3.4
            try? await Task.sleep(for: .seconds(dwell))
            if !Task.isCancelled { present(sceneIndex + 1) }
        }
    }
}
