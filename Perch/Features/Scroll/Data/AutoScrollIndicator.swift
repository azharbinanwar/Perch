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
    private let size: CGFloat = 34
    private lazy var glyph = GlyphView(frame: NSRect(x: 0, y: 0, width: size, height: size))
    private var window: NSWindow?

    /// Show (or move) the anchor centered on a global CoreGraphics point, reset to idle.
    func show(at cgPoint: CGPoint) {
        let win = window ?? makeWindow()
        window = win
        glyph.update(dx: 0, dy: 0)             // idle: dot only
        position(win, at: cgPoint)
        win.orderFront(nil)
    }

    /// Point the caret along a scroll displacement (0,0 = inside dead-zone → idle dot).
    func update(dx: CGFloat, dy: CGFloat) { glyph.update(dx: dx, dy: dy) }

    func hide() { window?.orderOut(nil) }

    private func makeWindow() -> NSWindow {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .statusBar
        win.ignoresMouseEvents = true          // click-through, never steals the scroll gesture
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
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
        ctx.rotate(by: angle)

        let caret = NSBezierPath()
        if showCaret {
            caret.move(to: CGPoint(x: -5, y: 3))
            caret.line(to: CGPoint(x: 0, y: 9))
            caret.line(to: CGPoint(x: 5, y: 3))
            caret.lineCapStyle = .round
            caret.lineJoinStyle = .round
        }

        // White outline layer (fat stroke + larger dot) with a soft grey glow behind it.
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 4, color: NSColor.gray.withAlphaComponent(0.6).cgColor)
        NSColor.white.setStroke()
        caret.lineWidth = 4.6
        caret.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: -3, y: -3, width: 6, height: 6)).fill()
        ctx.restoreGState()

        // Black glyph on top (no shadow).
        NSColor.black.setStroke()
        caret.lineWidth = 2.4
        caret.stroke()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: CGRect(x: -1.9, y: -1.9, width: 3.8, height: 3.8)).fill()

        ctx.restoreGState()
    }
}
