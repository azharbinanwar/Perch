//
//  HotKeyManager.swift
//  Perch
//
//  Global ⌘⇧V hotkey via Carbon. Fires from any app, needs no permission.
//

import Carbon.HIToolbox

final class HotKeyManager {
    /// Called when ⌘⇧V is pressed anywhere.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x50524348), id: 1)   // 'PRCH'
        RegisterEventHotKey(UInt32(kVK_ANSI_V),
                            UInt32(cmdKey | shiftKey),
                            id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
