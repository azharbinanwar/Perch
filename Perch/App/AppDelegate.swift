//
//  AppDelegate.swift
//  Perch
//
//  Owns all ViewModels, runs DI setup, keeps the app menu-bar only.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    // ViewModels — created once, injected into views via .environment().
    private(set) lazy var clipboardVM = ClipboardViewModel()
    private(set) lazy var scrollVM = ScrollViewModel()
    private(set) lazy var remapVM = RemapViewModel()
    private(set) lazy var settingsVM = SettingsViewModel()
    private(set) lazy var snippetVM = SnippetViewModel()

    // ⌘⇧V floating popup, hosted in its own NSPanel.
    private(set) lazy var clipboardPanel: ClipboardPanelController = {
        let model = ClipboardPopupModel(clipboard: clipboardVM, snippets: snippetVM)
        let controller = ClipboardPanelController(model: model)
        model.onPaste = { [weak controller] in controller?.completePaste() }
        model.onPasteKeepOpen = { [weak controller] in controller?.pasteKeepingOpen() }
        model.onClose = { [weak controller] in controller?.hide() }
        model.onOpenSettings = { [weak self, weak controller] in
            controller?.hide()
            self?.openMainWindow()
        }
        model.onBeginEdit = { [weak controller] in controller?.beginEdit() }
        model.onEndEdit = { [weak controller] in controller?.endEdit() }
        controller.setRoot(AnyView(ClipboardWindowView(model: model)))
        return controller
    }()

    private let hotKey = HotKeyManager()
    private var menuPreviousApp: NSRunningApplication?   // app focused when the menu opened
    private var openClipboardObserver: Any?
    private var hotKeyObserver: Any?

    /// Captured from SwiftUI so we can open the main window from AppKit contexts.
    var openWindowAction: ((String) -> Void)?

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let action = openWindowAction {
            action("main")
        } else if let win = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            win.makeKeyAndOrderFront(nil)   // fallback: front an existing titled window
        }
    }

    // MARK: - Menu actions

    /// Called when the menu opens — remember the app to paste back into.
    func captureMenuContext() {
        menuPreviousApp = NSWorkspace.shared.frontmostApplication
        clipboardVM.pruneExpired()   // lazy auto-clear on access
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardVM.handleTerminate()
    }

    /// Paste a peek item: copy, close the menu, refocus the previous app, then ⌘V.
    func menuPaste(_ item: ClipboardItem) {
        clipboardVM.pasteToPasteboard(item)
        let target = menuPreviousApp
        dismissMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            target?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                Paster.commandV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.clipboardVM.restoreClipboardIfNeeded()
                }
            }
        }
    }

    /// Best-effort close of the MenuBarExtra window.
    func dismissMenu() {
        for window in NSApp.windows where "\(type(of: window))".contains("MenuBarExtra") {
            window.close()
        }
    }

    override init() {
        super.init()
        setupDI()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar only, no dock icon
        clipboardVM.start()
        scrollVM.apply()          // re-enable saved scroll reversal
        remapVM.apply()           // re-enable saved key remaps
        settingsVM.applyLoginItem()

        // Global hotkey → toggle the clipboard popup from any app (only when enabled).
        hotKey.onTrigger = { [weak self] in
            guard let self, self.clipboardVM.isEnabled else { return }
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            guard self.clipboardVM.canOpenPopup(in: front) else { return }   // excluded app
            self.clipboardPanel.toggle()
        }
        hotKey.start(keyCode: settingsVM.hotKeyCode, modifiers: settingsVM.hotKeyModifiers)

        // Re-register when the user changes the shortcut.
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .hotKeyChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.hotKey.update(keyCode: self.settingsVM.hotKeyCode, modifiers: self.settingsVM.hotKeyModifiers)
        }

        // "Open Clipboard" from the main window → show the popup.
        openClipboardObserver = NotificationCenter.default.addObserver(
            forName: .openClipboardPopup, object: nil, queue: .main
        ) { [weak self] _ in
            self?.clipboardPanel.show()
        }
    }

    // MARK: - DI

    private func setupDI() {
        ServiceLocator.shared.register(ClipboardRepository.self) { ClipboardRepository() }
        ServiceLocator.shared.register(ClipboardMonitor.self)    { ClipboardMonitor() }
        ServiceLocator.shared.register(ScrollManager.self)       { ScrollManager() }
        ServiceLocator.shared.register(RemapRepository.self)     { RemapRepository() }
        ServiceLocator.shared.register(RemapManager.self)        { RemapManager() }
        ServiceLocator.shared.register(SettingsRepository.self)  { SettingsRepository() }
        ServiceLocator.shared.register(SnippetRepository.self)   { SnippetRepository() }
    }
}

extension Notification.Name {
    static let openClipboardPopup = Notification.Name("perch.openClipboardPopup")
    static let hotKeyChanged = Notification.Name("perch.hotKeyChanged")
}
