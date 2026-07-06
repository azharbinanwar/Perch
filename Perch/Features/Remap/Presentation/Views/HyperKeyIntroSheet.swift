//
//  HyperKeyIntroSheet.swift
//  Perch
//
//  Auto-playing Hyper Key demo on keycaps: Caps Lock lights up held, a letter taps,
//  and the full ⌘⌥⌃⇧ shortcut pops out — then the tap-alone and double-tap tricks.
//  Uses the shared IntroSheet frame, same pattern as the Mouse Shift demo.
//

import SwiftUI

struct HyperKeyIntroSheet: View {

    private struct Scene {
        let capsHeld: Bool          // Caps Lock held (amber) vs tapped
        let taps: Int               // quick taps on Caps Lock (when not held)
        let letter: String?         // key pressed while holding (nil = caps alone)
        let combo: String?          // the shortcut apps see (shown briefly, then the action)
        let action: String          // the payoff — what actually happens
        let actionIcon: String
        let caption: String
    }

    private let scenes: [Scene] = [
        Scene(capsHeld: true, taps: 0, letter: "W", combo: "⌘⌥⌃⇧W",
              action: "Open WhatsApp", actionIcon: "message.fill",
              caption: "Hold Caps Lock, press W — your messenger opens. Any key becomes a launcher."),
        Scene(capsHeld: true, taps: 0, letter: "S", combo: "⌘⌥⌃⇧S",
              action: "Screenshot – Area", actionIcon: "camera.viewfinder",
              caption: "Caps + S — grab a screenshot. Map any key in Shortcuts below: apps, scripts, window snapping…"),
        Scene(capsHeld: false, taps: 1, letter: nil, combo: nil,
              action: "Escape", actionIcon: "escape",
              caption: "A quick tap alone still does something useful — Escape, or whatever you pick."),
        Scene(capsHeld: false, taps: 2, letter: nil, combo: nil,
              action: "Caps Lock on/off", actionIcon: "capslock.fill",
              caption: "Double-tap to toggle real Caps Lock — nothing is lost."),
    ]

    @State private var capsLit = false
    @State private var letterLit = false
    @State private var shownLetter = "W"
    @State private var combo = ""              // "⌘⌥⌃⇧W" chip — the shortcut apps see
    @State private var result = ""             // the ACTION that fires — the real payoff
    @State private var resultIcon = "sparkles"
    @State private var caption = "Watch — Caps Lock becomes a super key."

    var body: some View {
        IntroSheet(title: "How the Hyper Key works",
                   subtitle: "Caps Lock, upgraded: hold it for a private shortcut layer.",
                   caption: caption,
                   tip: "Turn it on with the toggle, then record Hyper shortcuts below.") {
            HStack(spacing: 22) {
                // The stage: two keycaps doing the work.
                HStack(spacing: 12) {
                    keycap("caps lock", width: 110, lit: capsLit)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(shownLetterVisible ? 1 : 0)
                    keycap(shownLetter, width: 54, lit: letterLit)
                        .opacity(shownLetterVisible ? 1 : 0)
                }

                // The payoff: the shortcut apps see, then the ACTION it triggers —
                // the combo is the plumbing, the action is why you'd want this.
                VStack(spacing: 10) {
                    if !combo.isEmpty {
                        Text(combo)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                            .transition(.opacity)
                    }
                    if !result.isEmpty {
                        Label(result, systemImage: resultIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(duration: 0.35), value: result)
                .animation(.easeOut(duration: 0.2), value: combo)
            }
        }
        .task { await runLoop() }
    }

    private var shownLetterVisible: Bool { letterLit || capsLit }

    private func keycap(_ label: String, width: CGFloat, lit: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(lit ? Color.white : Color.primary)
            .frame(width: width, height: 44)
            .background(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(lit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: lit ? 1.5 : 1))
            .scaleEffect(lit ? 0.94 : 1)   // pressed keys sink a touch
            .animation(.easeOut(duration: 0.12), value: lit)
    }

    /// Endless loop: hold-and-press scenes, then the tap-alone and double-tap scenes.
    private func runLoop() async {
        do {
            while true {
                for scene in scenes {
                    caption = scene.caption
                    combo = ""
                    result = ""
                    capsLit = false
                    letterLit = false
                    try await Task.sleep(for: .milliseconds(700))

                    if scene.capsHeld, let letter = scene.letter {
                        shownLetter = letter
                        capsLit = true                         // finger down on caps
                        try await Task.sleep(for: .milliseconds(900))
                        letterLit = true                       // the letter taps
                        try await Task.sleep(for: .milliseconds(250))
                        combo = scene.combo ?? ""              // apps see the hyper shortcut…
                        try await Task.sleep(for: .milliseconds(500))
                        resultIcon = scene.actionIcon
                        result = scene.action                  // …and THIS is what it does
                        try await Task.sleep(for: .milliseconds(300))
                        letterLit = false
                        try await Task.sleep(for: .milliseconds(1900))
                        capsLit = false
                    } else {
                        for _ in 0..<max(1, scene.taps) {      // quick tap(s) on caps alone
                            capsLit = true
                            try await Task.sleep(for: .milliseconds(160))
                            capsLit = false
                            try await Task.sleep(for: .milliseconds(140))
                        }
                        try await Task.sleep(for: .milliseconds(250))
                        resultIcon = scene.actionIcon
                        result = scene.action
                        try await Task.sleep(for: .milliseconds(2100))
                    }
                }
            }
        } catch {}   // sheet dismissed → task cancelled
    }
}
