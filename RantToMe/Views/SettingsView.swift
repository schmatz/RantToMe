//
//  SettingsView.swift
//  RantToMe
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(GlossaryManager.self) private var glossaryManager
    @Environment(HotKeySettings.self) private var hotKeySettings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }

            SoundsSettingsView()
                .tabItem { Label("Sounds", systemImage: "speaker.wave.2") }

            GlossarySettingsView()
                .tabItem { Label("Glossary", systemImage: "text.badge.plus") }

            LLMSettingsView()
                .tabItem { Label("AI Cleanup", systemImage: "sparkles") }
        }
        .tabViewStyle(.grouped)
        .frame(width: 550, height: 450)
    }
}

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(HotKeySettings.self) private var hotKeySettings
    @State private var showDisableHistoryConfirmation = false
    @State private var showNoOutputWarning = false
    @State private var showClearHistoryConfirmation = false

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section {
                Picker("Speech Model", selection: $appState.selectedModelVersion) {
                    ForEach(AppModelVersion.allCases, id: \.self) { version in
                        Text(version.displayName).tag(version)
                    }
                }
                .onChange(of: appState.selectedModelVersion) { _, _ in
                    Task { await appState.reloadModelIfNeeded() }
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Parakeet v2: English-only, fastest. Parakeet v3: 25 European languages. Whisper: 100+ languages, slower.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Save transcription history", isOn: historyLoggingBinding)
                Toggle("Auto-copy to clipboard", isOn: autoCopyBinding)
                if appState.autoCopyEnabled {
                    Toggle("Auto-paste into active app", isOn: autoPasteBinding)
                        .padding(.leading, 20)
                    if appState.autoPasteEnabled && !AutoPasteService.checkAccessibilityPermission() {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Accessibility permission required")
                                .font(.caption)
                            Spacer()
                            Button("Grant Access") {
                                AutoPasteService.openAccessibilitySettings()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                        .padding(.leading, 20)
                    }
                }
                HStack {
                    Button("Clear History...") {
                        showClearHistoryConfirmation = true
                    }
                    .disabled(appState.history.isEmpty)
                    Spacer()
                    Text("\(appState.history.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("When history is disabled, transcriptions are not saved locally. Auto-paste requires Accessibility permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Toggle Recording") {
                    HotKeyRecorderView()
                }
                Toggle("Hold Fn key to record", isOn: fnKeyRecordingBinding)
                if appState.fnKeyRecordingEnabled && !FnKeyRecordingService.checkAccessibilityPermission() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Accessibility permission required")
                            .font(.caption)
                        Spacer()
                        Button("Grant Access") {
                            FnKeyRecordingService.openAccessibilitySettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            } header: {
                Text("Global Hotkey")
            } footer: {
                Text("Press the hotkey to toggle recording, or hold Fn to record while pressed. Fn key requires Accessibility permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Model Cache")
                        Text(appState.formattedCacheSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear & Restart") {
                        appState.clearCacheAndRestart()
                    }
                    .disabled(appState.modelCacheSize == 0)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Clears downloaded models and restarts the app. Models will be re-downloaded on next launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .padding()
        .alert("Disable History Logging?", isPresented: $showDisableHistoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                appState.historyLoggingEnabled = false
                if !appState.autoCopyEnabled {
                    showNoOutputWarning = true
                }
            }
        } message: {
            Text("Transcriptions will not be saved or appear in history. This cannot recover past transcriptions.")
        }
        .alert("No Output Destination", isPresented: $showNoOutputWarning) {
            Button("Enable Clipboard Copy") {
                appState.autoCopyEnabled = true
            }
        } message: {
            Text("Both history logging and auto-copy to clipboard are disabled. Transcriptions will have nowhere to go.")
        }
        .alert("Clear All History?", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                appState.clearAllHistory()
            }
        } message: {
            Text("This will permanently delete all \(appState.history.count) transcriptions. This cannot be undone.")
        }
    }

    private var historyLoggingBinding: Binding<Bool> {
        Binding(
            get: { appState.historyLoggingEnabled },
            set: { newValue in
                if !newValue {
                    showDisableHistoryConfirmation = true
                } else {
                    appState.historyLoggingEnabled = true
                }
            }
        )
    }

    private var autoCopyBinding: Binding<Bool> {
        Binding(
            get: { appState.autoCopyEnabled },
            set: { newValue in
                appState.autoCopyEnabled = newValue
                if !newValue && !appState.historyLoggingEnabled {
                    showNoOutputWarning = true
                }
            }
        )
    }

    private var autoPasteBinding: Binding<Bool> {
        Binding(
            get: { appState.autoPasteEnabled },
            set: { newValue in
                if newValue && !AutoPasteService.checkAccessibilityPermission() {
                    AutoPasteService.requestAccessibilityPermission()
                }
                appState.autoPasteEnabled = newValue
            }
        )
    }

    private var fnKeyRecordingBinding: Binding<Bool> {
        Binding(
            get: { appState.fnKeyRecordingEnabled },
            set: { newValue in
                if newValue && !FnKeyRecordingService.checkAccessibilityPermission() {
                    FnKeyRecordingService.requestAccessibilityPermission()
                }
                appState.fnKeyRecordingEnabled = newValue
            }
        )
    }
}

struct SoundsSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section {
                Toggle("Play sounds", isOn: $appState.soundsEnabled)
            } header: {
                Text("Feedback")
            }

            Section {
                SoundPickerRow(
                    label: "Recording starts",
                    selection: $appState.recordingStartSound
                )
                SoundPickerRow(
                    label: "Recording stops",
                    selection: $appState.recordingStopSound
                )
                SoundPickerRow(
                    label: "Transcription complete",
                    selection: $appState.transcriptionCompleteSound
                )
            } header: {
                Text("Sound Selection")
            }
            .disabled(!appState.soundsEnabled)
            .opacity(appState.soundsEnabled ? 1 : 0.5)
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SoundPickerRow: View {
    let label: String
    @Binding var selection: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(AppState.availableSounds, id: \.self) { sound in
                    Text(sound).tag(sound)
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Button {
                NSSound(named: NSSound.Name(selection))?.play()
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .help("Preview sound")
            .disabled(selection == "None")
        }
    }
}
