//
//  HotKeyManager.swift
//  Perch
//
//  Global hotkey via Carbon. Fires from any app, needs no permission. The key + modifiers
//  are configurable and can be re-registered at runtime.
//

import AppKit
import Carbon.HIToolbox

final class HotKeyManager {
    /// Called when the hotkey is pressed anywhere.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Install the handler (once) and register the given combo.
    func start(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        installHandlerIfNeeded()
        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    /// Re-register with a new combo (handler stays installed).
    func update(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
    }

    // MARK: - Private

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    private func registerHotKey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        let id = EventHotKeyID(signature: OSType(0x50524348), id: 1)   // 'PRCH'
        RegisterEventHotKey(keyCode, Self.carbonModifiers(modifiers),
                            id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}
