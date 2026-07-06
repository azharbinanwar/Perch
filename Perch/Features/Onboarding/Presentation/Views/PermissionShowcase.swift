//
//  PermissionShowcase.swift
//  Perch
//
//  The permission step's walkthrough: a mini Accessibility pane where the REAL flow
//  plays out — press +, add Perch to the list, flip its toggle on. The user watches
//  exactly what they're about to do in System Settings.
//

import SwiftUI

struct PermissionShowcase: View {

    private static let unlocks: [(icon: String, name: String)] = [
        ("computermouse", "Mouse"),
        ("keyboard", "Keys"),
        ("scroll", "Scroll"),
        ("doc.on.clipboard", "Quick paste"),
    ]

    @State private var plusPressed = false
    @State private var perchListed = false     // step 1: added via +
    @State private var toggleOn = false        // step 2: switch flipped
    @State private var litCount = 0            // step 3: features waking up, one by one
    @State private var unlocking = false       // pane → features handoff
    @State private var caption = "Watch — two steps in System Settings."

    var body: some View {
        VStack(spacing: 14) {
            // One stage: the Accessibility pane during add + enable, then it's REPLACED
            // by the features waking up. Fixed height so the caption never jumps.
            ZStack {
                if unlocking {
                    unlocksGrid.transition(.opacity)
                } else {
                    accessibilityPane.transition(.opacity)
                }
            }
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.3), value: unlocking)

            Text(caption)
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .task { await runLoop() }
    }

    // MARK: - The mini Accessibility pane (add + toggle)

    private var accessibilityPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "accessibility").font(.system(size: 11))
                Text("Accessibility").font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()

            appRow(icon: "keyboard", name: "Some Other App", on: true, highlight: false)
            Divider().padding(.leading, 12)
            if perchListed {
                perchRow
                Divider().padding(.leading, 12)
            }

            // The + / − footer — step one presses this.
            HStack(spacing: 10) {
                Text("+")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(plusPressed ? Color.white : .secondary)
                    .frame(width: 22, height: 18)
                    .background(plusPressed ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)),
                                in: RoundedRectangle(cornerRadius: 4))
                    .scaleEffect(plusPressed ? 0.9 : 1)
                    .animation(.easeOut(duration: 0.12), value: plusPressed)
                Text("−")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                    .frame(width: 22, height: 18)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
        }
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
        .animation(.spring(duration: 0.35), value: perchListed)
    }

    // MARK: - The payoff — everything it powers, waking up

    private var unlocksGrid: some View {
        HStack(spacing: 24) {
            ForEach(Array(Self.unlocks.enumerated()), id: \.offset) { i, feature in
                let lit = i < litCount
                VStack(spacing: 6) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                        .frame(width: 44, height: 44)
                        .background(lit ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04),
                                    in: RoundedRectangle(cornerRadius: 11))
                        .scaleEffect(lit ? 1 : 0.9)
                    Text(feature.name)
                        .font(.system(size: 10, weight: lit ? .semibold : .regular))
                        .foregroundStyle(lit ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                }
                .animation(.spring(duration: 0.35), value: litCount)
            }
        }
    }

    private var perchRow: some View {
        HStack(spacing: 8) {
            Image("perch")
                .resizable().scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.accentColor)
            Text("Perch").font(.system(size: 11.5, weight: .medium))
            Spacer()
            Capsule()
                .fill(toggleOn ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 32, height: 19)
                .overlay(alignment: toggleOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 15, height: 15).padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                }
                .animation(.spring(duration: 0.3), value: toggleOn)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func appRow(icon: String, name: String, on: Bool, highlight: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 14)
            Text(name).font(.system(size: 11.5)).foregroundStyle(.secondary)
            Spacer()
            Capsule()
                .fill(on ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.3))
                .frame(width: 32, height: 19)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 15, height: 15).padding(2)
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    /// The real grant flow, on a loop: press + → Perch joins the list → switch on →
    /// then everything it powers lights up.
    private func runLoop() async {
        do {
            while true {
                caption = "In System Settings → Privacy & Security → Accessibility…"
                unlocking = false
                plusPressed = false
                perchListed = false
                toggleOn = false
                litCount = 0
                try await Task.sleep(for: .milliseconds(1200))

                caption = "1. Press + and pick Perch from Applications"
                plusPressed = true
                try await Task.sleep(for: .milliseconds(250))
                plusPressed = false
                try await Task.sleep(for: .milliseconds(400))
                perchListed = true
                try await Task.sleep(for: .milliseconds(1600))

                caption = "2. Turn Perch on"
                toggleOn = true
                try await Task.sleep(for: .milliseconds(1100))

                // Hand off: the pane is replaced by everything it just unlocked.
                caption = "…and everything it powers wakes up."
                unlocking = true
                try await Task.sleep(for: .milliseconds(450))
                for i in 1...Self.unlocks.count {          // features light up one by one
                    litCount = i
                    try await Task.sleep(for: .milliseconds(340))
                }
                try await Task.sleep(for: .milliseconds(2200))
            }
        } catch {}   // view left the screen → task cancelled
    }
}
