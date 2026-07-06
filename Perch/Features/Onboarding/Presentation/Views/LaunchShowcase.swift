//
//  LaunchShowcase.swift
//  Perch
//
//  The finish step's living moment: a Mac logs in, the menu bar appears, and the
//  perch bird pops into place — "always there when you sit down", shown.
//

import SwiftUI

struct LaunchShowcase: View {

    @State private var barVisible = false
    @State private var birdIn = false
    @State private var ready = false

    var body: some View {
        VStack(spacing: 14) {
            // A mini menu bar (right side), the way it looks after login.
            HStack(spacing: 14) {
                Spacer()
                if birdIn {
                    Image("perch")
                        .resizable().scaledToFit()
                        .frame(width: 15, height: 15)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                Image(systemName: "wifi").font(.system(size: 11))
                Image(systemName: "battery.75").font(.system(size: 12))
                Text("Mon 9:41").font(.system(size: 11))
            }
            .foregroundStyle(.primary.opacity(0.8))
            .padding(.horizontal, 12)
            .frame(width: 300, height: 26)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.quaternary))
            .opacity(barVisible ? 1 : 0)
            .offset(y: barVisible ? 0 : -8)
            .animation(.spring(duration: 0.4), value: barVisible)
            .animation(.spring(duration: 0.35), value: birdIn)

            ZStack {
                if ready {
                    Label("Ready before you are", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .frame(height: 32)
            .animation(.spring(duration: 0.35), value: ready)
        }
        .task { await runLoop() }
    }

    private func runLoop() async {
        do {
            while true {
                barVisible = false
                birdIn = false
                ready = false
                try await Task.sleep(for: .milliseconds(800))
                barVisible = true                  // you log in — the menu bar appears
                try await Task.sleep(for: .milliseconds(700))
                birdIn = true                      // …and Perch is already there
                try await Task.sleep(for: .milliseconds(500))
                ready = true
                try await Task.sleep(for: .milliseconds(2600))
            }
        } catch {}   // view left the screen → task cancelled
    }
}
