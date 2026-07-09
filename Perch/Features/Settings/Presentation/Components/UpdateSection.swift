//
//  UpdateSection.swift
//  Perch
//
//  "Software updates" rows for the About group: manual check with live
//  status, download row when a new version exists, and a daily auto-check toggle.
//

import SwiftUI

struct UpdateSection: View {
    private var checker = UpdateChecker.shared
    @AppStorage("updates.autoCheck") private var autoCheck = true

    var body: some View {
        VStack(spacing: 10) {
            SettingRow(title: "Software updates",
                       subtitle: statusText,
                       icon: "arrow.down.circle") {
                trailingControl
            }

            if case .available(let version) = checker.phase {
                SettingRow(title: "Perch \(version) is available",
                           subtitle: "Downloads, verifies, and installs automatically — Perch relaunches when done.",
                           compact: true, indented: true) {
                    Button("Install Update") {
                        Task { await checker.downloadAndOpen() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if case .downloading(let progress) = checker.phase {
                HStack(spacing: 10) {
                    ProgressView(value: progress)
                        .controlSize(.small)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.leading, 32)   // aligns under the row text, matches `indented`
            }

            Divider()

            SettingRow(title: "Check automatically",
                       subtitle: "Look for new versions once a day, on launch.",
                       icon: "clock.arrow.circlepath") {
                Toggle("", isOn: $autoCheck).toggleStyle(.switch).labelsHidden()
            }
        }
    }

    // MARK: - Pieces

    private var statusText: String {
        switch checker.phase {
        case .idle:
            if let last = checker.lastChecked {
                return "Last checked \(last.formatted(.relative(presentation: .named)))."
            }
            return "See if a newer version of Perch is out."
        case .checking:
            return "Checking for updates…"
        case .upToDate:
            return "You're up to date — \(checker.currentVersion) is the latest version."
        case .available(let version):
            return "Version \(version) is ready to install."
        case .downloading:
            return "Downloading Perch.dmg…"
        case .installing:
            return "Installing — Perch will relaunch in a moment…"
        case .downloaded(let version):
            return "Auto-install couldn't complete — drag Perch \(version) from the opened DMG into Applications."
        case .failed(let message):
            return message
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch checker.phase {
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small)
        case .upToDate:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                checkButton("Check Again")
            }
        case .downloaded:
            Button("Open DMG") { checker.openDownloadedDMG() }
                .controlSize(.small)
        case .failed:
            checkButton("Retry")
        case .idle, .available:
            checkButton("Check for Updates")
        }
    }

    private func checkButton(_ label: String) -> some View {
        Button(label) { Task { await checker.check() } }
            .controlSize(.small)
    }
}
