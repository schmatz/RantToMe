//
//  AutoPasteService.swift
//  RantToMe
//

import ApplicationServices
import AppKit

@MainActor
final class AutoPasteService {
    /// Check if Accessibility permission is granted (without prompting)
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Request permission (shows system prompt)
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Open System Settings to Accessibility pane
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Perform Cmd+V paste using CGEvent
    static func performPaste() async -> Bool {
        guard checkAccessibilityPermission() else { return false }

        // Small delay to ensure clipboard is ready
        try? await Task.sleep(for: .milliseconds(100))

        let source = CGEventSource(stateID: .hidSystemState)

        // Virtual key code 0x09 = 'V' key
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
