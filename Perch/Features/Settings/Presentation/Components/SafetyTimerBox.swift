//
//  SafetyTimerBox.swift
//  Perch
//
//  Freeze-test safety net: arm a countdown; when it hits zero, Perch force-quits ITSELF
//  from a background thread (SIGKILL) — which fires even if the main thread is frozen, so a
//  hung app (e.g. an event-tap stall) releases and the Mac unfreezes without a reboot.
//  Plus a shortcut to the Accessibility pane for toggling Perch while testing.
//

import SwiftUI
import Darwin

struct SafetyTimerBox: View {
    @State private var seconds = 30
    @State private var remaining = 0
    @State private var armed = false
    @State private var killer: DispatchWorkItem?
    @State private var ticker: Timer?

    var body: some View {
        GroupBox("Safety timer (testing)") {
            VStack(spacing: 10) {
                SettingRow(title: "Force-quit Perch after a delay",
                           subtitle: "For freeze testing. Kills from a background thread, so it fires even if the app hangs — no reboot.") {
                    if armed {
                        HStack(spacing: 12) {
                            Text("\(remaining)s")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .frame(minWidth: 44, alignment: .trailing)
                            Button("Cancel") { disarm() }
                        }
                    } else {
                        HStack(spacing: 10) {
                            Stepper("\(seconds)s", value: $seconds, in: 5...300, step: 5)
                                .fixedSize()
                            Button("Arm") { arm() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                Divider()
                SettingRow(title: "Accessibility settings",
                           subtitle: "Open the pane to add or toggle Perch while testing.") {
                    Button("Open…") { AccessibilityService.shared.openSettings() }
                }
            }
            .padding(6)
        }
        .onDisappear { disarm() }
    }

    private func arm() {
        remaining = seconds
        armed = true

        // The KILLER — on a global (background) thread, so it runs even if the main thread is
        // frozen. SIGKILL is unconditional: the process dies instantly and its event taps release.
        let work = DispatchWorkItem { kill(getpid(), SIGKILL) }
        killer = work
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(seconds), execute: work)

        // The DISPLAY countdown — best-effort on the main thread. If the UI freezes it just stops
        // updating; the background killer above still fires on schedule.
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            remaining = max(0, remaining - 1)
            if remaining == 0 { ticker?.invalidate() }
        }
    }

    private func disarm() {
        killer?.cancel(); killer = nil
        ticker?.invalidate(); ticker = nil
        armed = false
    }
}
