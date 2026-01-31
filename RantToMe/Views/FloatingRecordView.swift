//
//  FloatingRecordView.swift
//  RantToMe
//

import SwiftUI

struct FloatingRecordView: View {
    @Environment(AppState.self) private var appState
    @Environment(HotKeySettings.self) private var hotKeySettings
    @Environment(\.openWindow) private var openWindow
    var onHide: (() -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 6) {
                bufoImage
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if appState.mode == .ready {
                            openWindow(id: "main")
                        }
                    }

                recordButton

                statusText
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(hotKeySettings.displayString) to toggle")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(width: 120, height: 150)

            HStack {
                Button {
                    onHide?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
            }
            .padding(6)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var bufoImage: some View {
        switch appState.mode {
        case .downloadRequired, .loadingModel:
            ProgressView()
                .scaleEffect(0.8)
        case .ready:
            if appState.frogeModeEnabled {
                Image("BufoFingerguns")
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.blue)
            }
        case .recording:
            if appState.frogeModeEnabled {
                GIFImage(name: "bufo-offers-a-loading-spinner")
                    .frame(width: 50, height: 50)
                    .clipped()
            } else {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
            }
        case .transcribing:
            if appState.frogeModeEnabled {
                Image("BufoApproval")
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "text.bubble.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var recordButton: some View {
        Button {
            Task {
                await appState.toggleRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(appState.mode == .recording ? Color.red : Color.red.opacity(0.8))
                    .frame(width: 44, height: 44)

                if appState.mode == .recording {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                } else if appState.mode == .transcribing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isRecordingEnabled)
        .opacity(isRecordingEnabled ? 1.0 : 0.5)
    }

    private var isRecordingEnabled: Bool {
        appState.mode == .ready || appState.mode == .recording
    }

    private var statusText: some View {
        Group {
            switch appState.mode {
            case .downloadRequired:
                Text("Setup required")
            case .loadingModel:
                if appState.modelLoadProgress > 0 {
                    Text("Loading \(Int(appState.modelLoadProgress * 100))%")
                } else {
                    Text("Loading...")
                }
            case .ready:
                Text("Ready")
            case .recording:
                Text("Recording...")
            case .transcribing:
                if appState.transcriptionProgress > 0 {
                    Text("Transcribing \(Int(appState.transcriptionProgress * 100))%")
                } else {
                    Text("Transcribing...")
                }
            }
        }
    }
}

#Preview {
    FloatingRecordView()
        .environment(AppState())
        .environment(HotKeySettings())
}
