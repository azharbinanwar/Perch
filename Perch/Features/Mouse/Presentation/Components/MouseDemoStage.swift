//
//  MouseDemoStage.swift
//  Perch
//
//  The ONE mouse demo animation, reused by the gate showcase and the in-app intro. A button on
//  the real MouseDiagramView lights up and the action it triggers flies in — touring the whole
//  feature set (remap, click/hold, gestures, Mouse Shift, scroll, swap). Publishes the running
//  caption via a binding so the surrounding frame narrates it. Mirrors ClipboardDemoStage.
//

import SwiftUI

struct MouseDemoStage: View {
    @Binding var caption: String
    var showDots = false

    /// Buttons that are "present" on the demo mouse (base + a couple of side extras).
    private static let active: Set<String> = ["left", "right", "middle", "top", "back", "fwd"]

    private struct Scene {
        let caption: String
        let button: String              // which diagram button lights
        var holdIDs: Set<String> = []   // amber HOLD layer key (Mouse Shift)
        let trigger: String             // e.g. "Middle click", "Hold Middle + Left", "Flick ↑"
        let actionIcon: String
        let actionLabel: String
    }

    private let scenes: [Scene] = [
        .init(caption: "Assign any button to an action or shortcut — even one that types a hotkey.",
              button: "middle", trigger: "Middle click", actionIcon: "square.grid.3x3.fill", actionLabel: "Mission Control"),
        .init(caption: "Every button gets click, double-click and hold — three actions each.",
              button: "back", trigger: "Hold Button 4", actionIcon: "doc.on.doc.fill", actionLabel: "Copy"),
        .init(caption: "Hold and flick in a direction for four more actions per button.",
              button: "top", trigger: "Flick ↑", actionIcon: "plus.rectangle.on.rectangle.fill", actionLabel: "New Desktop"),
        .init(caption: "Hold one button, press another — a whole second layer for every button.",
              button: "left", holdIDs: ["middle"], trigger: "Hold Middle → Left", actionIcon: "doc.on.clipboard.fill", actionLabel: "Paste"),
        .init(caption: "Reverse, smooth, flatten and speed up your scroll wheel — per app.",
              button: "middle", trigger: "Scroll wheel", actionIcon: "arrow.up.arrow.down", actionLabel: "Smooth scroll"),
        .init(caption: "Left-handed? Swap primary and secondary buttons in a tap.",
              button: "right", trigger: "Swap", actionIcon: "arrow.left.arrow.right", actionLabel: "Right = primary"),
    ]

    // MARK: - Live state

    @State private var sceneIndex = 0
    @State private var selected = ""
    @State private var holdIDs: Set<String> = []
    @State private var showAction = false
    @State private var keyTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?

    private var scene: Scene { scenes[sceneIndex] }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 8) {
                MouseDiagramView(
                    selected: $selected,
                    isMapped: { $0 == selected || holdIDs.contains($0) },
                    isActive: { Self.active.contains($0) },
                    holdIDs: holdIDs,
                    onSelect: { _ in }
                )
                .scaleEffect(0.72)
                .frame(width: 200, height: 250)

                actionCard
                    .frame(width: 150)
            }
            if showDots { dots }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { present(0) }
        .onDisappear { keyTask?.cancel(); advanceTask?.cancel() }
    }

    /// The "→ action fires" card that flies in after the button lights.
    private var actionCard: some View {
        VStack(spacing: 10) {
            Text(scene.trigger)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.quaternary, in: Capsule())

            Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)

            if showAction {
                VStack(spacing: 6) {
                    Image(systemName: scene.actionIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                    Text(scene.actionLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.25)))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
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

    // MARK: - Playback (mirrors ClipboardDemoStage)

    private func present(_ i: Int) {
        let n = ((i % scenes.count) + scenes.count) % scenes.count
        // Reset transient state SYNCHRONOUSLY (same update as the scene change) so the new
        // scene never renders the previous "fired" card for a frame — no flash.
        showAction = false
        selected = ""
        holdIDs = []
        sceneIndex = n
        caption = scenes[n].caption
        keyTask?.cancel()
        keyTask = Task { await play(scenes[n]) }
        scheduleAdvance()
    }

    private func play(_ s: Scene) async {
        try? await Task.sleep(for: .milliseconds(450))
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            holdIDs = s.holdIDs
            selected = s.button           // the button "presses" (lights up)
        }
        try? await Task.sleep(for: .milliseconds(450))
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { showAction = true }   // action fires
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .seconds(3.6))
            if !Task.isCancelled { present(sceneIndex + 1) }
        }
    }
}
