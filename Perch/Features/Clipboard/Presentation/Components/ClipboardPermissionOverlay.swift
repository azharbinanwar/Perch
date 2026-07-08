//
//  ClipboardPermissionOverlay.swift
//  Perch
//
//  The clipboard's Accessibility gate — the animated showcase on top (the reward) with a
//  compact amber "grant it" strip below, via the generic PermissionOverlay's intro slot.
//

import SwiftUI

struct ClipboardPermissionOverlay: View {
    var onGrant: () -> Void = { AccessibilityService.shared.request() }

    var body: some View {
        PermissionOverlay(
            icon: "accessibility",
            title: "Accessibility needed",
            message: "Keyboard navigation and quick paste are paused until you grant it.",
            grantTitle: "Grant",
            onGrant: onGrant,
            intro: AnyView(ClipboardIntroView()))
    }
}
