//
//  PerchPanel.swift
//  Perch
//
//  The popup's panel. Borderless panels can't become key by default; we allow it so that
//  the edit-before-paste text field can receive keystrokes. Normal browsing never makes it
//  key (it's shown with orderFrontRegardless), so the target app keeps focus as before.
//

import AppKit

final class PerchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
