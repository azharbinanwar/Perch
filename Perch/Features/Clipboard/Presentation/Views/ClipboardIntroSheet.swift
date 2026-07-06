//
//  ClipboardIntroSheet.swift
//  Perch
//
//  Auto-playing clipboard-popup demo: a key chip presses, and a mini popup reacts —
//  open with the hotkey, arrow through items, type to search, Enter to paste.
//  The popup is fully keyboard-driven; this shows the whole loop hands-on.
//

import SwiftUI

struct ClipboardIntroSheet: View {

    private static let items = ["Invoice #2041 — attached below", "hello@perch.app", "https://apple.com", "Meeting notes from Monday"]

    private struct Scene {
        let key: String                 // the key chip that presses
        let popupVisible: Bool
        let selected: Int               // highlighted row after the press
        let search: String              // text in the search bar
        let items: [Int]                // visible row indexes (search filters them)
        let pasted: String?             // non-nil → the paste payoff bubble
        let caption: String
    }

    private let scenes: [Scene] = [
        Scene(key: "⌘⇧V", popupVisible: true, selected: 0, search: "", items: [0, 1, 2, 3], pasted: nil,
              caption: "One shortcut opens your clipboard anywhere — the app you're in keeps focus."),
        Scene(key: "↓", popupVisible: true, selected: 1, search: "", items: [0, 1, 2, 3], pasted: nil,
              caption: "Arrow keys move through your copies — hands never leave the keyboard."),
        Scene(key: "i n v", popupVisible: true, selected: 0, search: "inv", items: [0], pasted: nil,
              caption: "Just start typing to search — no clicking a search box first."),
        Scene(key: "⏎", popupVisible: true, selected: 0, search: "inv", items: [0], pasted: "Pasted into your app",
              caption: "Enter pastes it right where you were typing. Copy once, paste forever."),
        Scene(key: "⌘2", popupVisible: true, selected: 1, search: "", items: [0, 1, 2, 3], pasted: "Pasted item 2",
              caption: "In a hurry? ⌘1–9 pastes an item instantly. Press ⌘/ inside for every shortcut."),
    ]

    @State private var keyLit = false
    @State private var shownKey = "⌘⇧V"
    @State private var popupVisible = false
    @State private var selected = 0
    @State private var search = ""
    @State private var visibleItems: [Int] = [0, 1, 2, 3]
    @State private var pasted = ""
    @State private var caption = "Watch — the whole thing runs from the keyboard."

    var body: some View {
        IntroSheet(title: "How the clipboard popup works",
                   subtitle: "Everything you copy, one shortcut away — fully keyboard-driven.",
                   caption: caption,
                   tip: "Try it now: press \u{2318}\u{21E7}V in any app.") {
            HStack(alignment: .center, spacing: 18) {
                keycap(shownKey, lit: keyLit)

                // The mini popup reacting to the key.
                VStack(spacing: 0) {
                    if popupVisible {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.secondary)
                            Text(search.isEmpty ? "Type to search…" : search)
                                .font(.system(size: 11))
                                .foregroundStyle(search.isEmpty ? .tertiary : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        Divider()
                        VStack(spacing: 2) {
                            ForEach(visibleItems, id: \.self) { i in
                                let isSel = visibleItems.firstIndex(of: i) == selected
                                HStack(spacing: 7) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 9))
                                        .foregroundStyle(isSel ? Color.white : .secondary)
                                    Text(Self.items[i])
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(isSel ? Color.white : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(isSel ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear),
                                            in: RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .padding(6)
                        // The payoff — pasting is the whole point.
                        if !pasted.isEmpty {
                            Divider()
                            Label(pasted, systemImage: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.vertical, 7)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                }
                .frame(width: 250)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                .opacity(popupVisible ? 1 : 0)
                .scaleEffect(popupVisible ? 1 : 0.9)
                .animation(.spring(duration: 0.3), value: popupVisible)
                .animation(.easeOut(duration: 0.18), value: selected)
                .animation(.easeOut(duration: 0.18), value: visibleItems)
                .animation(.spring(duration: 0.3), value: pasted)
            }
        }
        .task { await runLoop() }
    }

    private func keycap(_ label: String, lit: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(lit ? Color.white : Color.primary)
            .frame(width: 74, height: 40)
            .background(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(lit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: lit ? 1.5 : 1))
            .scaleEffect(lit ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: keyLit)
    }

    /// Per scene: the key presses, then the popup reacts — state lands after the tap.
    private func runLoop() async {
        do {
            while true {
                // Reset to "closed" between full loops.
                popupVisible = false
                pasted = ""
                search = ""
                selected = 0
                visibleItems = [0, 1, 2, 3]
                try await Task.sleep(for: .milliseconds(700))

                for scene in scenes {
                    caption = scene.caption
                    shownKey = scene.key
                    try await Task.sleep(for: .milliseconds(700))
                    keyLit = true
                    try await Task.sleep(for: .milliseconds(200))
                    keyLit = false

                    popupVisible = scene.popupVisible
                    selected = scene.selected
                    search = scene.search
                    visibleItems = scene.items
                    pasted = scene.pasted ?? ""
                    try await Task.sleep(for: .milliseconds(scene.pasted == nil ? 1900 : 2300))
                    if scene.pasted != nil { pasted = "" }
                }
            }
        } catch {}   // sheet dismissed → task cancelled
    }
}
