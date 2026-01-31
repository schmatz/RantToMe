//
//  MenuBarContentView.swift
//  RantToMe
//

import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(HotKeySettings.self) private var hotKeySettings
    @Environment(\.openWindow) private var openWindow
    let onToggleFloatingWindow: () -> Void

    var body: some View {
        @Bindable var appState = appState
        VStack(alignment: .leading, spacing: 0) {
            // Quick record button
            Button {
                Task {
                    await appState.toggleRecording()
                }
            } label: {
                HStack {
                    Image(systemName: appState.mode == .recording ? "stop.fill" : "mic.fill")
                        .foregroundStyle(appState.mode == .recording ? .red : .primary)
                    Text(appState.mode == .recording ? "Stop Recording" : "Start Recording (\(hotKeySettings.displayString))")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .disabled(appState.mode != .ready && appState.mode != .recording)

            Divider()

            // Toggle floating window
            Button {
                onToggleFloatingWindow()
            } label: {
                HStack {
                    Image(systemName: appState.isFloatingWindowVisible ? "eye.slash" : "eye")
                    Text(appState.isFloatingWindowVisible ? "Hide Floating Window" : "Show Floating Window")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Show main window
            Button {
                appState.selectedEntryIDs.removeAll()
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "rectangle.on.rectangle")
                    Text("Show Full Window")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Auto-copy setting
            Toggle(isOn: $appState.autoCopyEnabled) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Auto-copy to clipboard")
                }
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Settings
            Button {
                openWindow(id: "settings")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Help
            Button {
                openWindow(id: "help")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text("Help")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // About
            Button {
                openWindow(id: "about")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("About")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 220)
        .onReceive(NotificationCenter.default.publisher(for: .openFullWindow)) { _ in
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onChange(of: appState.shouldShowMainWindow) { _, shouldShow in
            if shouldShow {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
                appState.shouldShowMainWindow = false
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            statusIcon
                .frame(width: 12, height: 12)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch appState.mode {
        case .downloadRequired:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .loadingModel:
            ProgressView()
                .scaleEffect(0.5)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .recording:
            Image(systemName: "record.circle")
                .foregroundStyle(.red)
        case .transcribing:
            ProgressView()
                .scaleEffect(0.5)
        }
    }

    private var statusText: String {
        switch appState.mode {
        case .downloadRequired:
            return "Model setup required"
        case .loadingModel:
            if appState.modelLoadProgress > 0 {
                return "Loading model (\(Int(appState.modelLoadProgress * 100))%)"
            }
            return "Loading model..."
        case .ready:
            return "Ready to record"
        case .recording:
            return "Recording..."
        case .transcribing:
            if appState.transcriptionProgress > 0 {
                return "Transcribing (\(Int(appState.transcriptionProgress * 100))%)"
            }
            return "Transcribing..."
        }
    }
}
