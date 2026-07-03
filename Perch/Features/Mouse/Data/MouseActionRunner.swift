//
//  MouseActionRunner.swift
//  Perch
//
//  Performs a MouseAction: most are a synthesized keyboard shortcut; some launch an app/URL,
//  fire a media key, or hand off to Perch. Premium/automation kinds are no-ops for now.
//

import AppKit
import CoreGraphics

enum MouseActionRunner {

    static func run(_ action: MouseAction) {
        switch action.kind {
        case .disabled, .passThrough:
            return

        case .customKeystroke:
            if let code = action.keyCode {
                press(CGKeyCode(code), flags: CGEventFlags(rawValue: action.modifiers ?? 0))
            }

        case .openApp:   openApp(action.target)
        case .openFile:  if let p = action.target { NSWorkspace.shared.open(URL(fileURLWithPath: p)) }
        case .openURL:   if let s = action.target, let url = URL(string: s) { NSWorkspace.shared.open(url) }

        case .openClipboard:
            NotificationCenter.default.post(name: .openClipboardPopup, object: nil)
        case .pasteLast:
            press(9, flags: .maskCommand)   // ⌘V — the last item is already on the pasteboard

        case .missionControl: openApp("com.apple.exposelauncher")

        case .middleClick: click(.center, count: 1)
        case .doubleClick: click(.left, count: 2)
        case .tripleClick: click(.left, count: 3)

        case .screenshotWindow:               // ⌘⇧4 then Space
            press(21, flags: [.maskCommand, .maskShift])
            press(49, flags: [])

        case .playPause: mediaKey(16)
        case .nextTrack: mediaKey(17)
        case .prevTrack: mediaKey(18)
        case .volumeUp:  mediaKey(0)
        case .volumeDown: mediaKey(1)
        case .mute:      mediaKey(7)
        case .brightnessUp:   mediaKey(2)
        case .brightnessDown: mediaKey(3)

        case .runShortcut, .runAppleScript, .runShell, .macro:
            return   // premium — not wired yet

        default:
            if let (code, flags) = Self.keystroke(for: action.kind) { press(code, flags: flags) }
        }
    }

    // MARK: - Keyboard shortcut table (the bulk of the catalogue)

    private static func keystroke(for kind: MouseActionKind) -> (CGKeyCode, CGEventFlags)? {
        switch kind {
        case .copy:            return (8,  .maskCommand)
        case .cut:             return (7,  .maskCommand)
        case .paste:           return (9,  .maskCommand)
        case .pastePlain:      return (9,  [.maskCommand, .maskShift, .maskAlternate])
        case .undo:            return (6,  .maskCommand)
        case .redo:            return (6,  [.maskCommand, .maskShift])
        case .selectAll:       return (0,  .maskCommand)
        case .deleteKey:       return (51, [])
        case .back:            return (33, .maskCommand)   // ⌘[
        case .forward:         return (30, .maskCommand)   // ⌘]
        case .appExpose:       return (125, .maskControl)  // ⌃↓
        case .spotlight:       return (49, .maskCommand)   // ⌘Space
        case .prevSpace:       return (123, .maskControl)  // ⌃←
        case .nextSpace:       return (124, .maskControl)  // ⌃→
        case .screenshotArea:  return (21, [.maskCommand, .maskShift])  // ⌘⇧4
        case .screenshotFull:  return (20, [.maskCommand, .maskShift])  // ⌘⇧3
        case .screenshotTool:  return (23, [.maskCommand, .maskShift])  // ⌘⇧5
        case .minimizeWindow:  return (46, .maskCommand)   // ⌘M
        case .closeWindow:     return (13, .maskCommand)   // ⌘W
        case .lockScreen:      return (12, [.maskCommand, .maskControl])   // ⌃⌘Q
        default:               return nil
        }
    }

    // MARK: - Primitives

    private static func press(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }

    /// Synthesize a real click at the cursor. count = 1 middle, 2 double, 3 triple.
    private static func click(_ button: CGMouseButton, count: Int) {
        let position = CGEvent(source: nil)?.location ?? .zero
        let source = CGEventSource(stateID: .combinedSessionState)
        let downType: CGEventType = button == .left ? .leftMouseDown : (button == .right ? .rightMouseDown : .otherMouseDown)
        let upType: CGEventType = button == .left ? .leftMouseUp : (button == .right ? .rightMouseUp : .otherMouseUp)
        for i in 1...max(1, count) {
            for type in [downType, upType] {
                let event = CGEvent(mouseEventSource: source, mouseType: type,
                                    mouseCursorPosition: position, mouseButton: button)
                event?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
                event?.post(tap: .cgSessionEventTap)
            }
        }
    }

    private static func openApp(_ bundleID: String?) {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    /// Media/volume/brightness keys use system-defined events, not normal keystrokes.
    private static func mediaKey(_ key: Int32) {
        func post(_ down: Bool) {
            let data1 = Int((key << 16) | ((down ? 0xA : 0xB) << 8))
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        post(true)
        post(false)
    }
}
