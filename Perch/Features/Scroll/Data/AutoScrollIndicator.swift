//
//  AutoScrollIndicator.swift
//  Perch
//
//  The anchor shown at the press point while auto-scroll is active: a single caret + dot,
//  drawn white with a thin dark outline (caption style) so it reads on any background. The
//  dot alone marks the neutral anchor; the caret appears and rotates to the scroll direction.
//  A borderless, click-through overlay window owned by AutoScrollManager.
//

import AppKit

final class AutoScrollIndicator {
    private let size: CGFloat = 64
    private lazy var glyph = GlyphView(frame: NSRect(x: 0, y: 0, width: size, height: size))
    private var window: NSWindow?

    /// Show (or move) the anchor centered on a global CoreGraphics point, reset to idle.
    func show(at cgPoint: CGPoint) {
        let win = window ?? makeWindow()
        window = win
        glyph.update(dx: 0, dy: 0)             // idle: dot only
        position(win, at: cgPoint)
        win.orderFrontRegardless()             // Perch is inactive during scroll → plain orderFront is ignored
    }

    /// Point the caret along a scroll displacement (0,0 = inside dead-zone → idle dot).
    func update(dx: CGFloat, dy: CGFloat) { glyph.update(dx: dx, dy: dy) }

    func hide() { window?.orderOut(nil) }

    private func makeWindow() -> NSWindow {
        // Must be a non-activating NSPanel: plain NSWindows from a background app are not
        // admitted into another app's fullscreen Space, even with .fullScreenAuxiliary.
        let win = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        win.isFloatingPanel = true
        win.hidesOnDeactivate = false          // panel default is true → would vanish while Perch is inactive
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver               // above everything incl. another app's fullscreen space
        win.ignoresMouseEvents = true          // click-through, never steals the scroll gesture
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.contentView = glyph
        return win
    }

    // CG points are top-left origin; Cocoa windows are bottom-left. Flip against the primary
    // display height. ponytail: single/main-display case; fine until multi-display placement matters.
    private func position(_ win: NSWindow, at cg: CGPoint) {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        let height = primary?.frame.height ?? 0
        win.setFrameOrigin(NSPoint(x: cg.x - size / 2, y: height - cg.y - size / 2))
    }
}

/// Draws the caret + dot rotated toward the scroll direction. White fill, dark hairline outline.
private final class GlyphView: NSView {
    private var angle: CGFloat = 0     // radians; 0 = caret up
    private var showCaret = false

    func update(dx: CGFloat, dy: CGFloat) {
        if dx == 0 && dy == 0 {
            showCaret = false
        } else {
            showCaret = true
            // dy is screen-down-positive (CG); caret-up is +y here → this points it at the move.
            // Snap to the nearest 90° so the head only ever shows up / down / left / right.
            let quarter = CGFloat.pi / 2
            angle = (atan2(-dx, -dy) / quarter).rounded() * quarter
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.scaleBy(x: 0.8, y: 0.8)   // 20% smaller anchor
        ctx.setShadow(offset: .zero, blur: 5,
                      color: NSColor.black.withAlphaComponent(0.55).cgColor)

        let halo = NSColor.white.withAlphaComponent(0.9)   // outline
        let ink = NSColor.black                              // fill — matches the stock pointer

        // Anchor dot at the press point.
        halo.setFill()
        NSBezierPath(ovalIn: CGRect(x: -5, y: -5, width: 10, height: 10)).fill()
        ink.setFill()
        NSBezierPath(ovalIn: CGRect(x: -3.5, y: -3.5, width: 7, height: 7)).fill()

        // Solid triangle pointing the scroll direction (only while moving).
        if showCaret {
            ctx.rotate(by: angle)
            let tri = NSBezierPath()
            tri.move(to: CGPoint(x: -7, y: 11.5))
            tri.line(to: CGPoint(x: 0, y: 21))
            tri.line(to: CGPoint(x: 7, y: 11.5))
            tri.close()
            tri.lineJoinStyle = .round
            halo.setStroke(); tri.lineWidth = 3; tri.stroke()
            ink.setFill(); tri.fill()
        }
        ctx.restoreGState()
    }
}
