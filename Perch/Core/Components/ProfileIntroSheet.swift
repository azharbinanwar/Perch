//
//  ProfileIntroSheet.swift
//  Perch
//
//  Generic per-app-profile demo with the same rhythm as the other intros: an app comes
//  to the front, the SAME press happens, and a different action pops out — profiles
//  explained by watching one input change meaning, not by reading settings.
//  Each tab passes ITS OWN scenes (mouse presses on Mouse, key presses on Keys).
//

import SwiftUI

struct ProfileDemoScene {
    let appName: String
    let appIcon: String          // SF symbol standing in for the app
    let pressLabel: String       // the input — SAME across scenes (e.g. "Click Back")
    let pressIcon: String
    let action: String           // what fires in THIS app
    let actionIcon: String
    let highlighted: Bool        // true = special action (accent bubble), false = plain default
    let caption: String
}

struct ProfileIntroSheet: View {
    let title: String
    let subtitle: String
    let tip: String
    let scenes: [ProfileDemoScene]

    @State private var index = 0
    @State private var pressed = false     // the press chip pulses
    @State private var result = ""
    @State private var caption = "Watch — the same press, a different action per app."

    /// Each distinct app once, in first-appearance order (scenes may revisit an app).
    private var apps: [ProfileDemoScene] {
        var seen = Set<String>()
        return scenes.filter { seen.insert($0.appName).inserted }
    }

    var body: some View {
        IntroSheet(title: title, subtitle: subtitle, caption: caption, tip: tip) {
            HStack(spacing: 24) {
                // Who's in front — one tile per distinct app; scenes can revisit an app.
                VStack(spacing: 14) {
                    ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
                        appTile(app, front: app.appName == scenes[index].appName)
                    }
                }

                // The event: same press → this app's action.
                VStack(spacing: 12) {
                    HStack(spacing: 7) {
                        Image(systemName: scenes[index].pressIcon)
                        Text(scenes[index].pressLabel)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pressed ? Color.primary : .secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.primary.opacity(pressed ? 0.12 : 0.05), in: Capsule())
                    .scaleEffect(pressed ? 0.93 : 1)
                    .animation(.easeOut(duration: 0.12), value: pressed)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    ZStack {
                        if !result.isEmpty {
                            let lit = scenes[index].highlighted
                            Label(result, systemImage: scenes[index].actionIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(lit ? Color.accentColor : Color.secondary)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background((lit ? Color.accentColor : Color.secondary).opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 9))
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .frame(height: 40)
                    .animation(.spring(duration: 0.35), value: result)
                }
                .frame(maxWidth: .infinity)
            }
            .animation(.spring(duration: 0.45), value: index)
        }
        .task { await runLoop() }
    }

    private func appTile(_ scene: ProfileDemoScene, front: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: scene.appIcon)
                .font(.system(size: front ? 26 : 20))
                .foregroundStyle(front ? Color.accentColor : .secondary)
                .frame(width: front ? 58 : 46, height: front ? 58 : 46)
                .background(Color.primary.opacity(front ? 0.08 : 0.04),
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(front ? Color.accentColor : Color.clear, lineWidth: 2))
            Text(front ? "\(scene.appName) — in front" : scene.appName)
                .font(.system(size: 10, weight: front ? .semibold : .regular))
                .foregroundStyle(front ? Color.accentColor : .secondary)
        }
        .opacity(front ? 1 : 0.55)
        .scaleEffect(front ? 1 : 0.92)
    }

    /// Per scene: app comes to front → the press pulses → this app's action pops → next app.
    private func runLoop() async {
        do {
            while true {
                for i in scenes.indices {
                    index = i
                    caption = scenes[i].caption
                    result = ""
                    try await Task.sleep(for: .milliseconds(900))
                    pressed = true                       // the same input, every time
                    try await Task.sleep(for: .milliseconds(220))
                    pressed = false
                    try await Task.sleep(for: .milliseconds(150))
                    result = scenes[i].action            // …but THIS app's action fires
                    try await Task.sleep(for: .milliseconds(2400))
                }
            }
        } catch {}   // sheet dismissed → task cancelled
    }
}
