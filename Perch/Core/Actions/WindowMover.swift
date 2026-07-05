//
//  WindowMover.swift
//  Perch
//
//  The muscle behind the window-snapping actions: grabs the front app's focused window via
//  Accessibility and moves/resizes it on its own screen. Never touches Perch's own windows.
//

import AppKit
import ApplicationServices

enum WindowSnap {
    case leftHalf, rightHalf, maximize, center
}

enum WindowMover {

    static func apply(_ snap: WindowSnap) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let ref = windowRef, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return }
        let window = ref as! AXUIElement

        guard let current = frame(of: window),
              let fullHeight = NSScreen.screens.first?.frame.height else { return }

        // AX coordinates are top-left origin; NSScreen's are bottom-left. Find the window's
        // screen, then express its visible area (no menu bar / Dock) in AX coordinates.
        let appKitCenter = CGPoint(x: current.midX, y: fullHeight - current.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(appKitCenter) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        let area = CGRect(x: vf.origin.x, y: fullHeight - vf.maxY, width: vf.width, height: vf.height)

        let target: CGRect
        switch snap {
        case .leftHalf:
            target = CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height)
        case .rightHalf:
            target = CGRect(x: area.midX, y: area.minY, width: area.width / 2, height: area.height)
        case .maximize:
            target = area
        case .center:
            target = CGRect(x: area.midX - current.width / 2, y: area.midY - current.height / 2,
                            width: current.width, height: current.height)
        }

        set(window, position: target.origin, size: target.size)
    }

    // MARK: - AX plumbing

    private static func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posValue = posRef, CFGetTypeID(posValue) == AXValueGetTypeID(),
              let sizeValue = sizeRef, CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private static func set(_ window: AXUIElement, position: CGPoint, size: CGSize) {
        var p = position
        var s = size
        if let value = AXValueCreate(.cgPoint, &p) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &s) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        // Set size once more — some apps re-clamp position after the first resize.
        if let value = AXValueCreate(.cgSize, &s) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }
}
