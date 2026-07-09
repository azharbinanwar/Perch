//
//  PermissionOverlay.swift
//  Perch
//
//  Reusable "this feature needs a permission" lock. Frosts whatever's behind it, explains WHY,
//  optionally teases what unlocks, and offers a one-tap Grant (+ an optional secondary action).
//  Used by any module whose core can't run without a permission (Clipboard, Mouse, …).
//

import SwiftUI

struct PermissionOverlay: View {
    /// One "here's what you unlock" row.
    struct Unlock: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        var keys: String? = nil       // optional keycap chip on the right
    }

    var icon: String = "lock.fill"
    var title: String
    var message: String
    var unlocks: [Unlock] = []
    var unlocksHeader: String = "Once it's on"
    var grantTitle: String
    var onGrant: () -> Void
    var secondaryTitle: String? = nil            // e.g. "See what you'll unlock"
    var secondaryIcon: String = "play.circle"
    var onSecondary: (() -> Void)? = nil
    var footnote: String? = "Opens System Settings › Privacy & Security"
    /// Optional showcase shown ON TOP (the reward). The permission block sits below it.
    var intro: AnyView? = nil

    /// Permission = a *problem to fix*, so it uses the app's `warning` role, not the accent
    /// (which reads as "normal"). Central role → changing it re-tints every gate at once.
    private let warning = Color.warning

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)   // frost what's behind — "not usable right now"

            if intro != nil {
                // Showcase on top (the reward), a COMPACT amber strip below (action needed).
                VStack(spacing: 14) {
                    intro
                    compactStrip
                }
                .padding(18)
                .frame(maxWidth: 560)
            } else {
                // No intro → the fuller centered card (used until a module adds its demo).
                VStack(spacing: 14) {
                    iconView
                    headline
                    if !unlocks.isEmpty { unlockPanel }
                    grantButton
                    if let secondaryTitle, let onSecondary {
                        Button(action: onSecondary) {
                            HStack(spacing: 4) {
                                Image(systemName: secondaryIcon)
                                Text(secondaryTitle)
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                    if let footnote {
                        Text(footnote).font(.system(size: 10.5)).foregroundStyle(.tertiary)
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
            }
        }
    }

    /// Compact one-row amber warning: icon · title/message · small Grant. Fits under the demo,
    /// even in the small ⌘⇧V popup.
    private var compactStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(message)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: onGrant) {
                Text(grantTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(warning)
        }
        .padding(12)
        .background(warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(warning.opacity(0.25)))
        .frame(maxWidth: 480)
    }

    // MARK: - Pieces

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(warning)
            .frame(width: 54, height: 54)
            .background(warning.opacity(0.15), in: Circle())
            .overlay(Circle().stroke(warning.opacity(0.3), lineWidth: 1))
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
    }

    private var unlockPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(unlocksHeader)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.bottom, 8)

            ForEach(Array(unlocks.enumerated()), id: \.element.id) { i, item in
                if i > 0 { Divider().padding(.vertical, 8) }
                unlockRow(item)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))
    }

    private func unlockRow(_ item: Unlock) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(item.text).font(.system(size: 12.5)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let keys = item.keys {
                Chip(text: keys, size: .small)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var grantButton: some View {
        Button(action: onGrant) {
            Text(grantTitle)
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.borderedProminent)
        .tint(warning)                 // amber CTA — matches the "action needed" signal
        .frame(maxWidth: 220)
    }
}
