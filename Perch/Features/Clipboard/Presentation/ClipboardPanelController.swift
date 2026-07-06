//
//  ClipboardPanelController.swift
//  Perch
//
//  Hosts the ⌘⇧V popup in a floating, NON-activating panel that never takes keyboard
//  focus — so the app you were in keeps focus and paste lands there. While the popup is
//  open, a CGEventTap captures ↑↓ / Enter / Esc / typing and drives the popup model.
//

import AppKit
import SwiftUI
import CoreGraphics
import Carbon.HIToolbox

@MainActor
final class ClipboardPanelController {
    private let model: ClipboardPopupModel
    private var panel: NSPanel?
    private var rootView: AnyView = AnyView(EmptyView())

    private var keyTap: CFMachPort?
    private var keyTapSource: CFRunLoopSource?
    private var mouseMonitor: Any?
    private var appSwitchObserver: Any?

    init(model: ClipboardPopupModel) {
        self.model = model
    }

    func setRoot(_ view: AnyView) { rootView = view }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    /// Open straight onto the Snippets category (the "Open Snippets" action).
    func showSnippets() {
        show()
        model.setCategory(.snippets)
    }

    func show() {
        // paste + key capture both need Accessibility; prompt if missing.
        if !Permissions.isAccessibilityTrusted { Permissions.requestAccessibility() }

        model.open()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        centre(panel)
        panel.orderFrontRegardless()   // show WITHOUT activating Perch or taking key focus
        startKeyTap()
        model.needsPermission = (keyTap == nil)   // tap failed → keyboard control is off
        startMouseMonitor()
        startAppSwitchObserver()
    }

    func hide() {
        stopKeyTap()
        stopMouseMonitor()
        stopAppSwitchObserver()
        panel?.orderOut(nil)
    }

    // MARK: - Auto-close when another app is activated (so the key tap never lingers)

    private func startAppSwitchObserver() {
        guard appSwitchObserver == nil else { return }
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == Bundle.main.bundleIdentifier { return }   // ignore self
            self?.hide()
        }
    }

    private func stopAppSwitchObserver() {
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appSwitchObserver = nil
        }
    }

    // MARK: - Click-outside to dismiss (works without any permission)

    private func startMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor); mouseMonitor = nil }
    }

    /// Focus never left the target app, so just close and fire ⌘V into it.
    func completePaste() {
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            Self.sendCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.model.restoreClipboardIfNeeded()
            }
        }
    }

    // MARK: - Edit before paste

    /// Pause the key-tap and make the panel key so the edit text field receives typing.
    func beginEdit() {
        stopKeyTap()
        panel?.makeKeyAndOrderFront(nil)
    }

    /// Back to list browsing: resume the key-tap (the panel stays visible, target keeps focus
    /// because we never activated Perch).
    func endEdit() {
        startKeyTap()
    }

    // MARK: - Panel

    private func makePanel() -> NSPanel {
        let panel = PerchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }

    private func centre(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 60
        ))
    }

    // MARK: - Key tap (only while the popup is open)

    private func startKeyTap() {
        guard keyTap == nil, Permissions.isAccessibilityTrusted else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<ClipboardPanelController>.fromOpaque(refcon).takeUnretainedValue()
                return controller.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        keyTap = tap
        keyTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyTapSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopKeyTap() {
        if let tap = keyTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = keyTapSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        keyTap = nil
        keyTapSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let passThrough = Unmanaged.passUnretained(event)
        let flags = event.flags
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Never touch Ctrl combos (Ctrl+C etc.).
        if flags.contains(.maskControl) { return passThrough }

        // ⌘ combos — handle ours, pass the rest (incl. the ⌘⇧V toggle, which also has Shift).
        if flags.contains(.maskCommand) {
            if flags.contains(.maskShift) {
                if keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter {
                    model.pastePlainSelected(); return nil   // ⌘⇧⏎ paste plain
                }
                return passThrough
            }
            switch keyCode {
            case kVK_UpArrow:                      model.selectFirst();              return nil  // ⌘↑ top
            case kVK_DownArrow:                    model.selectLast();               return nil  // ⌘↓ bottom
            case kVK_Return, kVK_ANSI_KeypadEnter: model.pasteSelectedKeepingOpen(); return nil  // ⌘⏎ keep open
            case kVK_Delete:                       model.deleteSelected();           return nil  // ⌘⌫ delete item
            case kVK_ANSI_K:                       model.clearAll();                 return nil  // ⌘K clear all
            case kVK_ANSI_C:                       model.copySelectedWithoutPaste(); return nil  // ⌘C copy only
            case kVK_ANSI_Y:                       model.togglePreview();            return nil  // ⌘Y preview (always)
            case kVK_ANSI_P:                       model.togglePinSelected();        return nil  // ⌘P pin/unpin
            case kVK_ANSI_O:                       model.performOnSelected(.openLink);      return nil  // ⌘O open link
            case kVK_ANSI_R:                       model.performOnSelected(.revealInFinder); return nil  // ⌘R reveal
            case kVK_ANSI_S:                       model.performOnSelected(.saveImage);     return nil  // ⌘S save image
            case kVK_ANSI_E:                       model.startEditingSelected();     return nil  // ⌘E edit & paste
            case kVK_ANSI_Slash:                   model.toggleHelp();               return nil  // ⌘/ shortcuts
            default:
                if let n = Self.digit(forKeyCode: keyCode) { model.quickPick(n); return nil }   // ⌘1–9
                return passThrough
            }
        }

        // ⌥1–9 jump to a category.
        if flags.contains(.maskAlternate), let n = Self.digit(forKeyCode: keyCode) {
            model.selectCategory(n); return nil
        }

        // While previewing, ← → page the image carousel.
        if model.previewing {
            switch keyCode {
            case kVK_LeftArrow:  model.previewStep(-1); return nil
            case kVK_RightArrow: model.previewStep(1);  return nil
            default: break
            }
        }

        // Plain keys.
        switch keyCode {
        case kVK_UpArrow:                      model.moveUp();           return nil
        case kVK_DownArrow:                    model.moveDown();         return nil
        case kVK_Return, kVK_ANSI_KeypadEnter: model.pasteSelected();    return nil
        case kVK_Escape:                       model.escape();           return nil
        case kVK_Tab:   // ⇥ next category, ⇧⇥ previous (both wrap)
            model.cycleCategory(flags.contains(.maskShift) ? -1 : 1); return nil
        case kVK_Space:
            // Empty search → Space previews; mid-search → Space is a real space (phrases).
            if model.search.isEmpty { model.togglePreview() } else { model.appendToSearch(" ") }
            return nil
        case kVK_Delete:                       model.deleteSearchChar(); return nil
        default:
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
            if length > 0, let scalar = String(utf16CodeUnits: chars, count: length).unicodeScalars.first,
               scalar.value >= 32, scalar.value != 127 {
                model.appendToSearch(String(scalar))
                return nil
            }
            return passThrough
        }
    }

    private static func digit(forKeyCode code: Int) -> Int? {
        switch code {
        case kVK_ANSI_1: return 1
        case kVK_ANSI_2: return 2
        case kVK_ANSI_3: return 3
        case kVK_ANSI_4: return 4
        case kVK_ANSI_5: return 5
        case kVK_ANSI_6: return 6
        case kVK_ANSI_7: return 7
        case kVK_ANSI_8: return 8
        case kVK_ANSI_9: return 9
        default: return nil
        }
    }

    func pasteKeepingOpen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            Self.sendCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.model.restoreClipboardIfNeeded()
            }
        }
    }

    private static func sendCommandV() { Paster.commandV() }
}
