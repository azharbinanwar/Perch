//
//  PermissionTile.swift
//  Perch
//
//  Generic "this module needs a permission" tile, shown at the TOP of a page (not an overlay).
//  The real controls stay visible-but-dimmed underneath, so the user sees what they unlock.
//  Two actions: Grant (fixes it) and an optional "What you get" (opens the module's showcase).
//

import SwiftUI

struct PermissionTile: View {
    var icon: String = "accessibility"
    var title: String
    var message: String
    var grantTitle: String = "Grant Access"
    var onGrant: () -> Void
    /// Optional — shows a secondary button that opens the module's intro/showcase sheet.
    var introTitle: String = "What you get"
    var onShowIntro: (() -> Void)? = nil

    /// Permission = a problem to fix → the app's `warning` role, never the accent.
    private let warning = Color.warning

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(warning)
                .frame(width: 44, height: 44)
                .background(warning.opacity(0.15), in: Circle())
                .overlay(Circle().stroke(warning.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(action: onGrant) {
                        Text(grantTitle)
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 16).padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(warning)

                    if let onShowIntro {
                        Button(action: onShowIntro) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text(introTitle)
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(warning)
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(warning.opacity(0.25)))
    }
}
