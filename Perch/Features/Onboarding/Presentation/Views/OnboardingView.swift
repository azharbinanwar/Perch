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
    @State private var trusted = Permissions.isAccessibilityTrusted

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

            Spacer()
            content.frame(maxWidth: 440).padding(.horizontal, 40)
            Spacer()

            footer.padding(.horizontal, 40).padding(.bottom, 28)
        }
        .frame(minWidth: 640, minHeight: 470)
        .onAppear { trusted = Permissions.isAccessibilityTrusted }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:  welcome
        case 1:  permission
        default: finish
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 20) {
            hero("bird.fill", "Welcome to Perch", "The little Mac utilities macOS forgot — all in your menu bar.")
            VStack(spacing: 12) {
                featureRow("doc.on.clipboard", "Clipboard", "Full copy history — search it, pin it, paste it with one shortcut.")
                featureRow("text.quote", "Snippets", "Type ;sig; anywhere and it becomes your saved text — with live dates and your clipboard inside.")
                featureRow("computermouse", "Mouse", "Give every button a job — clicks, holds, gestures, smooth scrolling. Different per app.")
                featureRow("keyboard", "Keys", "Remap keys, turn Caps Lock into a super-shortcut key, double-tap modifiers. Different per app.")
            }
        }
    }

    private var permission: some View {
        VStack(spacing: 20) {
            hero("hand.raised.fill", "One permission unlocks it all",
                 "Mouse, Keys, Scroll and quick clipboard paste use macOS Accessibility. Clipboard history works without it.")
            if trusted {
                Label("Accessibility granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.green)
            } else {
                Button {
                    Permissions.requestAccessibility()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { trusted = Permissions.isAccessibilityTrusted }
                } label: {
                    Label("Grant Accessibility…", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
    }

    private var finish: some View {
        @Bindable var vm = settings
        return VStack(spacing: 20) {
            hero("checkmark.seal.fill", "You're all set",
                 "Perch lives in your menu bar — click the bird up top anytime.")
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
                }
                Button(step == lastStep ? "Get Started" : "Continue") {
                    if step == lastStep { onFinish() } else { withAnimation { step += 1 } }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Pieces

    private func hero(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(Color.accentColor)
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private func featureRow(_ icon: String, _ name: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.accentColor).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .semibold))
                Text(desc).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
