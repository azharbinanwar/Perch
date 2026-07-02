//
//  Paster.swift
//  Perch
//
//  Synthesizes ⌘V into the focused app. Requires Accessibility permission.
//

import CoreGraphics

enum Paster {
    static func commandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)   // V
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
