//
//  ContentView.swift
//  RantToMe
//
//  Created by Michael Schmatz on 1/16/26.
//

import Combine
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var timerTick = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            HistorySidebarView(
                history: appState.history,
                selection: $appState.selectedEntryIDs,
                onDelete: { entries in
                    appState.deleteEntries(entries)
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            detailView
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.selectedEntryIDs.removeAll()
                } label: {
                    Label("New Recording", systemImage: "plus.circle")
                }
                .disabled(appState.mode != .ready && appState.mode != .recording)
            }
        }
        .onKeyPress(.escape) {
            if !appState.selectedEntryIDs.isEmpty {
                appState.selectedEntryIDs.removeAll()
                return .handled
            }
            return .ignored
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.clearError() } }
        )) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.mode {
        case .downloadRequired:
            ModelDownloadView {
                Task {
                    await appState.downloadModel()
                }
            }

        case .loadingModel:
            VStack(spacing: 20) {
                if appState.modelLoadProgress > 0 {
                    ProgressView(value: appState.modelLoadProgress)
                        .frame(width: 300)

                    Text("\(Int(appState.modelLoadProgress * 100))%")
                        .font(.title2)
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(height: 24)
                }

                Text(appState.modelLoadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 300)

                if appState.showClearCacheButton {
                    Button("Clear cache and restart app") {
                        appState.clearCacheAndRestart()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(40)
            .onReceive(timer) { _ in
                timerTick += 1  // Force view refresh to check showClearCacheButton
            }

        case .ready, .recording:
            readyView

        case .transcribing:
            VStack(spacing: 16) {
                if appState.frogeModeEnabled {
                    Image("BufoApproval")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                } else {
                    Image(systemName: "text.bubble.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.green)
                }

                if appState.transcriptionProgress > 0 {
                    ProgressView(value: appState.transcriptionProgress)
                        .frame(width: 200)
                    Text("\(Int(appState.transcriptionProgress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Transcribing...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var readyView: some View {
        if let entry = appState.singleSelectedEntry {
            TranscriptionDetailView(entry: entry) { text in
                appState.copyToClipboard(text)
            }
        } else if appState.selectedEntryIDs.count > 1 {
            VStack(spacing: 16) {
                Image(systemName: "doc.on.doc")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("\(appState.selectedEntryIDs.count) items selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Button("Copy All Text") {
                    let combinedText = appState.selectedEntries
                        .map { $0.text }
                        .joined(separator: "\n\n---\n\n")
                    appState.copyToClipboard(combinedText)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 32) {
                if appState.mode == .recording {
                    if appState.frogeModeEnabled {
                        GIFImage(name: "bufo-offers-a-loading-spinner")
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "mic.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, options: .repeating)
                    }
                } else {
                    if appState.frogeModeEnabled {
                        Image("BufoFingerguns")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "waveform.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.blue)
                    }
                }

                RecordButtonView(
                    isRecording: appState.mode == .recording,
                    isEnabled: appState.mode == .ready || appState.mode == .recording
                ) {
                    Task {
                        await appState.toggleRecording()
                    }
                }

                Text(appState.mode == .recording ? "Recording... Click to stop" : "Click to record")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if appState.mode != .recording {
                    DropZoneView(isEnabled: appState.mode == .ready) { url in
                        Task {
                            await appState.transcribeFile(at: url)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
