//
//  FnKeyRecordingService.swift
//  RantToMe
//

import ApplicationServices
import AppKit
import os.log

private let logger = Logger(subsystem: "com.rantto.me", category: "FnKeyRecording")

@MainActor
final class FnKeyRecordingService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnKeyDown = false
    private var onFnKeyStateChanged: ((Bool) -> Void)?

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

    func start(onFnKeyStateChanged: @escaping (Bool) -> Void) -> Bool {
        guard Self.checkAccessibilityPermission() else { return false }

        self.onFnKeyStateChanged = onFnKeyStateChanged

        // Create event tap for flagsChanged events (modifier keys)
        let eventMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        // We need to use a pointer to self for the callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<FnKeyRecordingService>.fromOpaque(userInfo).takeUnretainedValue()
                return service.handleEvent(event)
            },
            userInfo: selfPointer
        ) else {
            return false
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        onFnKeyStateChanged = nil
        isFnKeyDown = false
    }

    private nonisolated func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let eventTime = CFAbsoluteTimeGetCurrent()
        let flags = event.flags

        // Check if fn key is pressed (maskSecondaryFn)
        let fnKeyPressed = flags.contains(.maskSecondaryFn)

        // Check if other modifiers are pressed (for Fn+key combos like Fn+Delete)
        let otherModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        let hasOtherModifiers = !flags.intersection(otherModifiers).isEmpty

        // Only notify on state change
        Task { @MainActor in
            let taskStart = CFAbsoluteTimeGetCurrent()
            logger.info("⏱️ FnKey event tap Task started, fnKeyPressed=\(fnKeyPressed), delay from event=\((taskStart - eventTime) * 1000)ms")

            if fnKeyPressed != self.isFnKeyDown {
                self.isFnKeyDown = fnKeyPressed
                logger.info("⏱️ FnKey state changed, calling onFnKeyStateChanged")
                self.onFnKeyStateChanged?(fnKeyPressed)
                logger.info("⏱️ FnKey onFnKeyStateChanged returned, elapsed=\((CFAbsoluteTimeGetCurrent() - taskStart) * 1000)ms")
            }
        }

        // Consume Fn-only events to prevent emoji picker from opening.
        // Let Fn+other modifier combinations pass through for system shortcuts.
        if !hasOtherModifiers {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        // Note: stop() must be called before deinit since it's @MainActor
    }
}
