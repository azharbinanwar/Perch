//
//  KeysDemoStage.swift
//  Perch
//
//  The ONE keys demo animation: the input keys press (big keycaps) → an arrow down → the
//  action it produces flies in, same as the mouse demo's action card. Tours remap, Hyper Key,
//  double-tap and open-app. Publishes the running caption via a binding.
//

import SwiftUI

struct KeysDemoStage: View {
    @Binding var caption: String
    var showDots = false

    private struct Scene {
        let caption: String
        let keys: [String]          // input keycaps that press
        let output: String          // result — a combo or an action/app name
        var outputIcon: String? = nil   // non-nil → action (icon + label), else a keycap combo
        var pulse: Bool = false     // double-tap: flash the keys twice
    }

    private let scenes: [Scene] = [
        .init(caption: "Remap any key or shortcut, app by app — great for Windows muscle memory.",
              keys: ["⌃", "C"], output: "⌘C"),
        .init(caption: "Caps Lock becomes a Hyper Key — ⌘⌥⌃⇧ at once, a private layer no app fights.",
              keys: ["⇪ Caps Lock"], output: "⌘⌥⌃⇧"),
        .init(caption: "Tap a modifier twice to run an action — normal shortcuts never fire.",
              keys: ["⇧", "⇧"], output: "Spotlight", outputIcon: "magnifyingglass", pulse: true),
        .init(caption: "Map a shortcut to launch any app instantly.",
              keys: ["⇧", "⌘", "T"], output: "Terminal", outputIcon: "terminal"),
    ]

    @State private var sceneIndex = 0
    @State private var lit = false
    @State private var showResult = false
    @State private var keyTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?

    private var scene: Scene { scenes[sceneIndex] }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(Array(scene.keys.enumerated()), id: \.offset) { _, k in
                    keycap(k)
                }
            }
            .frame(height: 56)

            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)

            // ZStack reserves the row's height even when the result is hidden between scenes,
            // so the dots below never jump up/down as it clears and reappears.
            ZStack { result }.frame(height: 56)

            if showDots { dots }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { present(0) }
        .onDisappear { keyTask?.cancel(); advanceTask?.cancel() }
    }

    private func keycap(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(lit ? Color.white : .primary)
            .frame(minWidth: 50, minHeight: 50)
            .padding(.horizontal, 12)
            .background(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .stroke(lit ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: lit ? 1.5 : 1))
            .scaleEffect(lit ? 0.95 : 1)
            .shadow(color: lit ? Color.accentColor.opacity(0.4) : .clear, radius: 7)
    }

    @ViewBuilder
    private var result: some View {
        if showResult {
            if let icon = scene.outputIcon {
                HStack(spacing: 7) {
                    Image(systemName: icon).font(.system(size: 18))
                    Text(scene.output).font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.accentColor.opacity(0.25)))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Text(scene.output)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 11))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }

    // MARK: - Dots + nav

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

    private func present(_ i: Int) {
        let n = ((i % scenes.count) + scenes.count) % scenes.count
        showResult = false          // reset sync so the next result never flashes
        lit = false
        sceneIndex = n
        caption = scenes[n].caption
        keyTask?.cancel()
        keyTask = Task { await play(scenes[n]) }
        scheduleAdvance()
    }

    private func play(_ s: Scene) async {
        try? await Task.sleep(for: .milliseconds(450))
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { lit = true }
        if s.pulse {   // double-tap "tap twice" feel
            try? await Task.sleep(for: .milliseconds(170))
            withAnimation(.easeOut(duration: 0.1)) { lit = false }
            try? await Task.sleep(for: .milliseconds(110))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { lit = true }
        }
        try? await Task.sleep(for: .milliseconds(380))
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { showResult = true }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .seconds(3.6))
            if !Task.isCancelled { present(sceneIndex + 1) }
        }
    }
}
