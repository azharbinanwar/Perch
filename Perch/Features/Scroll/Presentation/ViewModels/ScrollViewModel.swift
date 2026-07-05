//
//  ScrollViewModel.swift
//  Perch
//
//  Mouse scroll settings: reverse direction, flat (no-acceleration) scrolling, and speed.
//  All three feed one ScrollConfig applied to the manager (which taps only when needed).
//

import Observation
import Foundation

@Observable
final class ScrollViewModel {
    private(set) var isEnabled: Bool     // reverse direction (name kept for existing bindings)
    private(set) var linear: Bool        // flat, no acceleration
    private(set) var smooth: Bool        // glide wheel ticks instead of jumping
    private(set) var speed: Double       // multiplier
    private(set) var needsPermission = false

    // Auto-scroll: hold a button + move to scroll.
    private(set) var autoScroll: Bool
    private(set) var autoScrollButton: Int
    private(set) var autoScrollSpeed: Double

    private let manager: ScrollManager
    private let autoManager: AutoScrollManager
    private let defaults = UserDefaults.standard

    init(manager: ScrollManager = ServiceLocator.shared.resolve(ScrollManager.self),
         autoManager: AutoScrollManager = ServiceLocator.shared.resolve(AutoScrollManager.self)) {
        self.manager = manager
        self.autoManager = autoManager
        self.isEnabled = defaults.bool(forKey: Keys.Defaults.scrollReversed)
        self.linear = defaults.bool(forKey: Keys.Defaults.scrollLinear)
        self.smooth = defaults.bool(forKey: Keys.Defaults.scrollSmooth)
        self.speed = defaults.object(forKey: Keys.Defaults.scrollSpeed) as? Double ?? 1
        self.autoScroll = defaults.bool(forKey: Keys.Defaults.autoScrollOn)
        self.autoScrollButton = defaults.object(forKey: Keys.Defaults.autoScrollButton) as? Int ?? 2
        self.autoScrollSpeed = defaults.object(forKey: Keys.Defaults.autoScrollSpeed) as? Double ?? 1
    }

    /// Re-apply saved settings at launch.
    func apply() { push(); pushAuto() }

    /// Re-read from storage and re-apply (used after Import).
    func reload() {
        isEnabled = defaults.bool(forKey: Keys.Defaults.scrollReversed)
        linear = defaults.bool(forKey: Keys.Defaults.scrollLinear)
        smooth = defaults.bool(forKey: Keys.Defaults.scrollSmooth)
        speed = defaults.object(forKey: Keys.Defaults.scrollSpeed) as? Double ?? 1
        autoScroll = defaults.bool(forKey: Keys.Defaults.autoScrollOn)
        autoScrollButton = defaults.object(forKey: Keys.Defaults.autoScrollButton) as? Int ?? 2
        autoScrollSpeed = defaults.object(forKey: Keys.Defaults.autoScrollSpeed) as? Double ?? 1
        apply()
    }

    func toggle() {
        isEnabled.toggle()
        defaults.set(isEnabled, forKey: Keys.Defaults.scrollReversed)
        push()
    }

    func setSmooth(_ on: Bool) {
        smooth = on
        defaults.set(on, forKey: Keys.Defaults.scrollSmooth)
        push()
    }

    func setLinear(_ on: Bool) {
        linear = on
        defaults.set(on, forKey: Keys.Defaults.scrollLinear)
        push()
    }

    func setSpeed(_ value: Double) {
        speed = value
        defaults.set(value, forKey: Keys.Defaults.scrollSpeed)
        push()
    }

    func setAutoScroll(_ on: Bool) {
        autoScroll = on
        defaults.set(on, forKey: Keys.Defaults.autoScrollOn)
        pushAuto()
    }

    func setAutoScrollButton(_ button: Int) {
        autoScrollButton = button
        defaults.set(button, forKey: Keys.Defaults.autoScrollButton)
        pushAuto()
    }

    func setAutoScrollSpeed(_ value: Double) {
        autoScrollSpeed = value
        defaults.set(value, forKey: Keys.Defaults.autoScrollSpeed)
        pushAuto()
    }

    private var config: ScrollConfig {
        ScrollConfig(reversed: isEnabled, linear: linear, speed: speed, smooth: smooth)
    }

    private func push() {
        if config.active, !Permissions.isAccessibilityTrusted {
            Permissions.requestAccessibility()
        }
        needsPermission = !manager.apply(config)
    }

    private func pushAuto() {
        if autoScroll, !Permissions.isAccessibilityTrusted {
            Permissions.requestAccessibility()
        }
        let ok = autoManager.apply(enabled: autoScroll, triggerButton: autoScrollButton, sensitivity: autoScrollSpeed)
        if !ok { needsPermission = true }
    }
}
