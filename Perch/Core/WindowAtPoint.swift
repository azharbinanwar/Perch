//
//  WindowAtPoint.swift
//  Perch
//
//  Which app owns the window under a screen point. Scroll and auto-scroll are cursor-based
//  (macOS scrolls the window under the pointer without activating it), so both engines
//  resolve their per-app config through this one helper.
//

import AppKit
import CoreGraphics

enum WindowAtPoint {

    struct Info {
        let bundleID: String?
        let bounds: CGRect
    }

    /// The topmost normal-layer window containing the point (front-to-back scan).
    static func info(under point: CGPoint) -> Info? {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        for window in windows {
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.contains(point),
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t else { continue }
            return Info(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
                        bounds: bounds)
        }
        return nil
    }
}
