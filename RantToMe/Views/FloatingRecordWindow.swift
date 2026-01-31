//
//  FloatingRecordWindow.swift
//  RantToMe
//

import AppKit
import SwiftUI

class FloatingRecordWindow: NSPanel {
    init<Content: View>(contentView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = self.contentRect(forFrameRect: frame)
        self.contentView = hostingView

        // Position in top-right corner of screen by default
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - frame.width - 20
            let y = screenFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    // Allow the window to become key for button clicks but not activate the app
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class FloatingWindowController: NSWindowController {
    convenience init<Content: View>(contentView: Content) {
        let window = FloatingRecordWindow(contentView: contentView)
        self.init(window: window)
    }

    func show() {
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}
