//
//  ClipboardPermissionOverlay.swift
//  Perch
//
//  Shown over the ⌘⇧V popup while Accessibility is missing. Without it the popup can't
//  navigate by keyboard or paste, so a thin banner isn't enough — this frosts the list,
//  explains WHY in context, teases what unlocks, and offers a one-tap Grant.
//

import SwiftUI

struct ClipboardPermissionOverlay: View {
    var onGrant: () -> Void = { AccessibilityService.shared.request() }
    var onSeeDemo: () -> Void = {}

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)   // frost the list behind — "not usable right now"

            VStack(spacing: 18) {
                icon
                headline
                unlockPanel
                grantButton

                Button(action: onSeeDemo) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle")
                        Text("See what you'll unlock")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Text("Opens System Settings › Privacy & Security")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(28)
            .frame(maxWidth: 360)
        }
    }

    // MARK: - Pieces

    private var icon: some View {
        Image(systemName: "accessibility")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .frame(width: 60, height: 60)
            .background(Color.accentColor.opacity(0.14), in: Circle())
            .overlay(Circle().stroke(Color.accentColor.opacity(0.25), lineWidth: 1))
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text("Turn on the clipboard")
                .font(.system(size: 17, weight: .semibold))
            Text("Perch types into your other apps to paste — that needs Accessibility. Until it's on, keyboard navigation and quick paste stay asleep here.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
    }

    /// A little "here's what you get" panel — reward framing beats a bare demand.
    private var unlockPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Once it's on")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.bottom, 8)

            unlockRow(icon: "doc.on.clipboard.fill", text: "Paste anything you've copied", keys: "⇧⌘V")
            divider
            unlockRow(icon: "bolt.fill", text: "Grab your last copies in a tap", keys: "⌘1–9")
            divider
            unlockRow(icon: "magnifyingglass", text: "Find any clip as you type", keys: "type")
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))
    }

    private var divider: some View {
        Divider().padding(.vertical, 8)
    }

    private func unlockRow(icon: String, text: String, keys: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            keycap(keys)
        }
    }

    private func keycap(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
    }

    private var grantButton: some View {
        Button(action: onGrant) {
            Text("Grant Accessibility")
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: 220)
    }
}
