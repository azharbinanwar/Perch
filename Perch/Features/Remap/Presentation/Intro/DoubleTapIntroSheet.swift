//
//  DoubleTapIntroSheet.swift
//  Perch
//
//  Auto-playing Double-Tap demo: a modifier keycap taps twice quickly and its action pops
//  out — while a slow single press shows normal shortcuts are never touched. Shared
//  IntroSheet frame, same rhythm as the Hyper Key demo.
//

import SwiftUI

struct DoubleTapIntroSheet: View {

    private struct Scene {
        let key: String             // the modifier cap, e.g. "⇧ shift"
        let taps: Int               // 2 = double-tap fires; 1 = normal press, nothing fires
        let action: String
        let actionIcon: String
        let fires: Bool             // false = the "normal shortcuts still work" scene
        let caption: String
    }

    private let scenes: [Scene] = [
        Scene(key: "⇧ shift", taps: 2, action: "Spotlight", actionIcon: "magnifyingglass", fires: true,
              caption: "Tap Shift twice, quickly — Spotlight opens. No other key needed."),
        Scene(key: "⌘ command", taps: 2, action: "Open Clipboard", actionIcon: "doc.on.clipboard", fires: true,
              caption: "Each modifier gets its own action — double-tap ⌘ for your clipboard."),
        Scene(key: "⇧ shift", taps: 1, action: "Nothing — just ⇧", actionIcon: "checkmark", fires: false,
              caption: "A normal press stays a normal press — your everyday shortcuts are never affected."),
    ]

    @State private var keyLit = false
    @State private var shownKey = "⇧ shift"
    @State private var result = ""
    @State private var resultIcon = "sparkles"
    @State private var resultFires = true
    @State private var caption = "Watch — two quick taps on a modifier."

    var body: some View {
        IntroSheet(title: "How Double-Tap works",
                   subtitle: "Tap a modifier key twice quickly to run an action.",
                   caption: caption,
                   tip: "Turn it on with the toggle, then pick an action per modifier.") {
            HStack(spacing: 22) {
                keycap(shownKey, lit: keyLit)

                // The payoff bubble — grey when the scene shows "nothing happens".
                VStack {
                    if !result.isEmpty {
                        Label(result, systemImage: resultIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(resultFires ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background((resultFires ? Color.accentColor : Color.secondary).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(duration: 0.35), value: result)
            }
        }
        .task { await runLoop() }
    }

    private func keycap(_ label: String, lit: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(lit ? Color.white : Color.primary)
            .frame(width: 120, height: 44)
            .background(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(lit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: lit ? 1.5 : 1))
            .scaleEffect(lit ? 0.94 : 1)   // pressed keys sink a touch
            .animation(.easeOut(duration: 0.12), value: lit)
    }

    /// Endless loop: tap-tap → action pops; the single-press scene shows nothing firing.
    private func runLoop() async {
        do {
            while true {
                for scene in scenes {
                    caption = scene.caption
                    result = ""
                    keyLit = false
                    shownKey = scene.key
                    try await Task.sleep(for: .milliseconds(800))

                    if scene.taps == 2 {
                        for _ in 0..<2 {                       // two quick visible taps
                            keyLit = true
                            try await Task.sleep(for: .milliseconds(150))
                            keyLit = false
                            try await Task.sleep(for: .milliseconds(120))
                        }
                    } else {
                        keyLit = true                          // one slow, ordinary press
                        try await Task.sleep(for: .milliseconds(700))
                        keyLit = false
                    }
                    try await Task.sleep(for: .milliseconds(250))
                    resultIcon = scene.actionIcon
                    resultFires = scene.fires
                    result = scene.action
                    try await Task.sleep(for: .milliseconds(2200))
                }
            }
        } catch {}   // sheet dismissed → task cancelled
    }
}
