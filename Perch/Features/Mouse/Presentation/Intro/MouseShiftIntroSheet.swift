//
//  MouseShiftIntroSheet.swift
//  Perch
//
//  Auto-playing Mouse Shift demo on the real mouse diagram: a hold button goes amber
//  (HOLD), another button flashes, and the combo's action pops up — looping through a
//  few combos so the "hold + click = second action" idea explains itself.
//

import SwiftUI

struct MouseShiftIntroSheet: View {

    private enum Press: String { case click = "Click", doubleClick = "Double click", hold = "Hold" }

    private struct Combo {
        let hold: String        // diagram hotspot that powers the layer
        let target: String      // hotspot pressed while holding
        let press: Press        // how the target is pressed
        let action: String      // what fires
        let caption: String
    }

    private let combos: [Combo] = [
        Combo(hold: "back", target: "left", press: .click, action: "Spotlight",
              caption: "Hold Back, click Left — it runs Spotlight instead of a normal click."),
        Combo(hold: "back", target: "left", press: .doubleClick, action: "Mission Control",
              caption: "Same buttons, DOUBLE-click — its own action. Click, double click and hold are separate slots."),
        Combo(hold: "back", target: "right", press: .hold, action: "Screenshot – Area",
              caption: "Hold Back and keep Right pressed down — the Hold slot fires."),
        Combo(hold: "fwd", target: "left", press: .click, action: "Paste as Plain Text",
              caption: "A second hold key has its OWN combo set — Forward + Left does something else."),
    ]

    @State private var holdIDs: Set<String> = []
    @State private var flashID = ""            // target button lit for the press moment
    @State private var pressLabel = ""         // "CLICK" / "DOUBLE CLICK" / "HOLD" chip
    @State private var firedAction = ""        // "✨ Spotlight" bubble
    @State private var caption = "Watch — hold one button, press another."

    var body: some View {
        IntroSheet(title: "How Mouse Shift works",
                   subtitle: "One button held down gives every other button a second action.",
                   caption: caption,
                   tip: "Set your own combos right below this dialog.") {
            HStack(spacing: 24) {
                MouseDiagramView(selected: $flashID,
                                 isMapped: { _ in false },
                                 isActive: { ["left", "right", "middle", "top", "back", "fwd"].contains($0) },
                                 holdIDs: holdIDs,
                                 onSelect: { _ in })   // display only — taps do nothing here
                    .scaleEffect(0.82)
                    .frame(width: 220, height: 280)

                // The payoff: how it was pressed + what fired, appearing at the click moment.
                VStack(spacing: 10) {
                    if !pressLabel.isEmpty {
                        Text(pressLabel)
                            .font(.system(size: 11, weight: .semibold)).kerning(0.4)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                            .transition(.opacity)
                    }
                    if !firedAction.isEmpty {
                        Label(firedAction, systemImage: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondaryAccent)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.secondaryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(duration: 0.35), value: firedAction)
                .animation(.easeOut(duration: 0.2), value: pressLabel)
            }
        }
        .task { await runLoop() }
    }

    /// Endless loop: engage the hold (amber), press the target its way, pop the action, release.
    private func runLoop() async {
        do {
            while true {
                for combo in combos {
                    caption = combo.caption
                    firedAction = ""
                    pressLabel = ""
                    flashID = ""
                    holdIDs = []
                    try await Task.sleep(for: .milliseconds(700))
                    holdIDs = [combo.hold]                      // finger goes down — amber HOLD
                    try await Task.sleep(for: .milliseconds(1000))
                    pressLabel = combo.press.rawValue.uppercased()

                    switch combo.press {
                    case .click:
                        flashID = combo.target
                        try await Task.sleep(for: .milliseconds(350))
                    case .doubleClick:                          // two quick visible taps
                        for _ in 0..<2 {
                            flashID = combo.target
                            try await Task.sleep(for: .milliseconds(180))
                            flashID = ""
                            try await Task.sleep(for: .milliseconds(120))
                        }
                        flashID = combo.target
                    case .hold:                                 // stays pressed, action after the delay
                        flashID = combo.target
                        try await Task.sleep(for: .milliseconds(900))
                    }

                    firedAction = combo.action                  // ✨ the second action fires
                    try await Task.sleep(for: .milliseconds(1900))
                    flashID = ""
                    holdIDs = []                                // release
                    try await Task.sleep(for: .milliseconds(600))
                }
            }
        } catch {}   // sheet dismissed → task cancelled
    }
}
