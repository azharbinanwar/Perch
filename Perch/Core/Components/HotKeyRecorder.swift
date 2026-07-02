//
//  HotKeyRecorder.swift
//  Perch
//
//  Reusable "press a shortcut" recorder. Shows the current combo; on click it captures
//  the next key-with-modifiers and reports (keyCode, modifiers, label).
//

import SwiftUI
import Carbon.HIToolbox

struct HotKeyRecorder: View {
    let display: String
    let onRecord: (UInt32, NSEvent.ModifierFlags, String) -> Void

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button { recording ? stop() : start() } label: {
            Text(recording ? "Press keys…" : display)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(recording ? Color.accentColor : .primary)
                .frame(minWidth: 56)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(recording ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.quaternary),
                            in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(recording ? Color.accentColor : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }   // global hotkeys need a modifier
            onRecord(UInt32(event.keyCode), mods, Self.keyLabel(event))
            stop()
            return nil   // consume
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }

    // MARK: - Display helpers

    static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    static func keyLabel(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:  return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab:    return "⇥"
        case kVK_Escape: return "esc"
        case kVK_Delete: return "⌫"
        default:
            if let chars = event.charactersIgnoringModifiers, let first = chars.first, !first.isWhitespace {
                return String(first).uppercased()
            }
            return "Key\(event.keyCode)"
        }
    }
}
