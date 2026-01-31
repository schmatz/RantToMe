//
//  GlobalHotKeyManager.swift
//  RantToMe
//
//  Created by Michael Schmatz on 1/16/26.
//

import Carbon
import AppKit

class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onToggle: () -> Void
    private var currentKeyCode: UInt32
    private var currentModifiers: UInt32

    init(keyCode: UInt32 = UInt32(kVK_ANSI_D), modifiers: UInt32 = UInt32(cmdKey), onToggle: @escaping () -> Void) {
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
        self.onToggle = onToggle
        installEventHandler()
        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID(signature: fourCharCode("FROG"), id: 1)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                           GetApplicationEventTarget(), 0, &hotKeyRef)

        currentKeyCode = keyCode
        currentModifiers = modifiers
    }

    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func updateHotKey(keyCode: UInt32, modifiers: UInt32) {
        // Don't update if nothing changed
        guard keyCode != currentKeyCode || modifiers != currentModifiers else { return }

        unregisterHotKey()
        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    func triggerToggle() {
        onToggle()
    }

    deinit {
        unregisterHotKey()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

// Helper to create OSType from string
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + OSType(char)
    }
    return result
}

// C function callback that bridges to Swift
private func hotKeyHandler(nextHandler: EventHandlerCallRef?,
                           event: EventRef?,
                           userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.triggerToggle()
    }
    return noErr
}
