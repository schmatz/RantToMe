//
//  HotKeyRecorderView.swift
//  RantToMe
//

import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorderView: View {
    @Environment(HotKeySettings.self) private var hotKeySettings
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var showInvalidWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
            Text(isRecording ? "Press a key..." : hotKeySettings.displayString)
                .frame(width: 120)
                .padding(8)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                )

            Button(isRecording ? "Cancel" : "Record Hotkey") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .buttonStyle(.borderedProminent)
            }

            if showInvalidWarning {
                Text("Use F1-F20, or add ⌘/⌃/⌥")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        // Add local event monitor for key down events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Get key code
            let keyCode = UInt32(event.keyCode)

            // Convert NSEvent modifier flags to Carbon modifiers
            var carbonModifiers: UInt32 = 0
            if event.modifierFlags.contains(.command) {
                carbonModifiers |= UInt32(cmdKey)
            }
            if event.modifierFlags.contains(.shift) {
                carbonModifiers |= UInt32(shiftKey)
            }
            if event.modifierFlags.contains(.option) {
                carbonModifiers |= UInt32(optionKey)
            }
            if event.modifierFlags.contains(.control) {
                carbonModifiers |= UInt32(controlKey)
            }

            // Ignore Escape key - use it to cancel
            if keyCode == UInt32(kVK_Escape) {
                self.stopRecording()
                return nil
            }

            // Don't allow modifier-only hotkeys (like just pressing Shift)
            let isModifierOnlyKey = [
                kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
                kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
                kVK_Function, kVK_CapsLock
            ].contains(Int(keyCode))

            if isModifierOnlyKey {
                return nil
            }

            // Validate the hotkey combination
            if !self.isValidHotKey(keyCode: keyCode, modifiers: carbonModifiers) {
                self.showInvalidWarning = true
                // Don't accept - keep recording
                return nil
            }

            self.showInvalidWarning = false

            // Update the hotkey settings
            self.hotKeySettings.keyCode = keyCode
            self.hotKeySettings.modifiers = carbonModifiers
            self.hotKeySettings.save()

            // Post notification that hotkey changed
            NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)

            self.stopRecording()

            // Consume the event
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        showInvalidWarning = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Check if this is a valid global hotkey combination.
    /// Function keys (F1-F20) work alone, other keys require ⌘, ⌃, or ⌥ (not just Shift).
    private func isValidHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // Function keys always work (F1-F20)
        let functionKeys: [Int] = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
            kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
        ]
        if functionKeys.contains(Int(keyCode)) {
            return true
        }

        // For other keys, require at least ⌘, ⌃, or ⌥ (not just Shift)
        let hasCommandOrControlOrOption =
            (modifiers & UInt32(cmdKey) != 0) ||
            (modifiers & UInt32(controlKey) != 0) ||
            (modifiers & UInt32(optionKey) != 0)

        return hasCommandOrControlOrOption
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("hotKeyDidChange")
}
