//
//  RantToMeApp.swift
//  RantToMe
//
//  Created by Michael Schmatz on 1/16/26.
//

import SwiftUI

@main
struct RantToMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar with dropdown
        MenuBarExtra {
            MenuBarContentView(
                onToggleFloatingWindow: {
                    appDelegate.toggleFloatingWindow()
                }
            )
            .environment(appDelegate.appState)
            .environment(appDelegate.hotKeySettings)
        } label: {
            menuBarIcon
        }

        // Main window (history view) - hidden by default
        Window("RantToMe", id: "main") {
            ContentView()
                .environment(appDelegate.appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)

        // About window
        Window("About RantToMe", id: "about") {
            AboutView()
                .environment(appDelegate.appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Settings window
        Window("Settings", id: "settings") {
            SettingsView()
                .environment(appDelegate.appState)
                .environment(appDelegate.appState.glossaryManager)
                .environment(appDelegate.hotKeySettings)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Help window
        Window("Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Recording") {
                    appDelegate.appState.selectedEntryIDs.removeAll()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(appDelegate.appState.mode != .ready && appDelegate.appState.mode != .recording)
            }

            CommandGroup(after: .appInfo) {
                Button("Toggle Recording") {
                    Task {
                        await appDelegate.appState.toggleRecording()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appDelegate.appState.mode != .ready && appDelegate.appState.mode != .recording)
            }
        }
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        switch appDelegate.appState.mode {
        case .downloadRequired:
            Image(systemName: "exclamationmark.triangle")
        case .loadingModel:
            Image(systemName: "arrow.down.circle")
        case .ready:
            if appDelegate.appState.frogeModeEnabled, let nsImage = NSImage(named: "BufoHappy") {
                Image(nsImage: {
                    nsImage.size = NSSize(width: 18, height: 18)
                    return nsImage
                }())
            } else {
                Image(systemName: "waveform")
            }
        case .recording:
            Image(systemName: "record.circle")
                .symbolRenderingMode(.multicolor)
        case .transcribing:
            Image(systemName: "text.bubble")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindowController: FloatingWindowController?
    let appState = AppState()
    let hotKeySettings = HotKeySettings()
    var globalHotKeyManager: GlobalHotKeyManager?
    private var hotKeyObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close the default windows on launch - we want menu bar + floating window only
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApplication.shared.windows {
                if window.title == "RantToMe" ||
                   window.title == "About RantToMe" ||
                   window.title == "Settings" ||
                   window.title == "Help" {
                    window.close()
                }
            }
        }

        // Initialize global hotkey with saved settings
        globalHotKeyManager = GlobalHotKeyManager(
            keyCode: hotKeySettings.keyCode,
            modifiers: hotKeySettings.modifiers
        ) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.appState.toggleRecording()
            }
        }

        // Listen for hotkey changes
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .hotKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.globalHotKeyManager?.updateHotKey(
                keyCode: self.hotKeySettings.keyCode,
                modifiers: self.hotKeySettings.modifiers
            )
        }

        // Create and show floating window on launch
        DispatchQueue.main.async { [self] in
            createFloatingWindow()
        }
    }

    @MainActor
    func createFloatingWindow() {
        let floatingView = FloatingRecordView(onHide: { [weak self] in
            self?.toggleFloatingWindow()
        })
            .environment(appState)
            .environment(hotKeySettings)
        floatingWindowController = FloatingWindowController(contentView: floatingView)
        floatingWindowController?.show()
        appState.isFloatingWindowVisible = true
    }

    @MainActor
    func toggleFloatingWindow() {
        if floatingWindowController == nil {
            createFloatingWindow()
        } else {
            floatingWindowController?.toggle()
        }
        appState.isFloatingWindowVisible = floatingWindowController?.isVisible ?? false
    }
}
