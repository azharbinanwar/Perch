//
//  OnboardingView.swift
//  Perch
//
//  First-run walkthrough: what Perch does → grant Accessibility → launch-at-login, then done.
//  Shown once (RootWindowView swaps to the main window after). Reuses SettingRow + app styling.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(SettingsViewModel.self) private var settings
    @State private var step = 0
    @State private var trusted = AccessibilityService.shared.trusted

    private let lastStep = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if step < lastStep {
                    Button("Skip") { onFinish() }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)

            // Vertically centered (the old feel) — hero + step body sit together as one
            // block, so it always looks balanced whatever the body's height.
            Spacer()
            VStack(spacing: 22) {
                heroBlock
                stepBody
            }
            .frame(maxWidth: 440).padding(.horizontal, 40)
            Spacer()

            footer.padding(.horizontal, 40).padding(.bottom, 28)
        }
        .frame(minWidth: 640, minHeight: 580)   // tall enough for the animated welcome on a FRESH launch
        .onAppear { trusted = AccessibilityService.shared.trusted }
        .task(id: step) {
            // While the permission step is up, watch for the grant — the status flips to
            // green the moment the user allows it in System Settings, no clicks needed.
            guard step == 1 else { return }
            while !Task.isCancelled {
                trusted = AccessibilityService.shared.trusted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Hero (one fixed slot; only the text/icon inside change per step)

    private var heroBlock: some View {
        VStack(spacing: 0) {
            Group {
                if step == 0 {
                    // The vector logo — crisp, no tile, tinted accent.
                    Image("perch").resizable().scaledToFit()
                        .frame(width: 74, height: 74)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: heroIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(height: 78)   // icon zone constant → title/subtitle never shift between steps

            Text(heroTitle)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text(heroSubtitle)
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)   // two-line reserve so a longer subtitle doesn't nudge the body
                .padding(.top, 6)
        }
        .frame(maxWidth: 460)
    }

    private var heroIcon: String { step == 1 ? "hand.raised.fill" : "checkmark.seal.fill" }
    private var heroTitle: String {
        switch step {
        case 0:  return "Welcome to Perch"
        case 1:  return "One permission unlocks it all"
        default: return "You're all set"
        }
    }
    private var heroSubtitle: String {
        switch step {
        case 0:  return "The little Mac utilities macOS forgot — all in your menu bar."
        case 1:  return "Mouse, Keys, Scroll and quick paste use macOS Accessibility. Clipboard works without it."
        default: return "Perch lives in your menu bar — click the bird up top anytime."
        }
    }

    // MARK: - Step bodies (only this region changes; the hero above stays fixed)

    @ViewBuilder private var stepBody: some View {
        switch step {
        case 0:  WelcomeShowcase()
        case 1:  permissionBody
        default: finishBody
        }
    }

    private var permissionBody: some View {
        VStack(spacing: 20) {
            PermissionShowcase()
            if trusted {
                Label("Accessibility granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.green)
            } else {
                Button {
                    // The macOS prompt only ever shows once — the deep link ALWAYS lands
                    // the user in the right pane, so repeat clicks never feel dead.
                    AccessibilityService.shared.request()   // prompts and opens the pane
                } label: {
                    Label("Open Accessibility Settings…", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
    }

    private var finishBody: some View {
        @Bindable var vm = settings
        return VStack(spacing: 20) {
            LaunchShowcase()
            GroupBox {
                SettingRow(title: "Launch at login", subtitle: "Start Perch automatically when you log in.") {
                    Toggle("", isOn: $vm.settings.openAtLogin).toggleStyle(.switch).labelsHidden()
                }
                .padding(6)
            }
            .frame(maxWidth: 360)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0...lastStep, id: \.self) { i in
                    Circle().fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.bordered).controlSize(.large)   // same size & shape as Continue
                }
                Button(step == lastStep ? "Get Started" : "Continue") {
                    if step == lastStep { onFinish() } else { withAnimation { step += 1 } }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }
    }

}
