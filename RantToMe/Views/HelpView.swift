//
//  HelpView.swift
//  RantToMe
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        TabView {
            GettingStartedTab()
                .tabItem { Label("Getting Started", systemImage: "play.circle") }

            RecordingTab()
                .tabItem { Label("Recording", systemImage: "mic") }

            ModelsTab()
                .tabItem { Label("Models", systemImage: "cpu") }

            FeaturesTab()
                .tabItem { Label("Features", systemImage: "star") }

            TipsTab()
                .tabItem { Label("Tips", systemImage: "lightbulb") }
        }
        .tabViewStyle(.grouped)
        .frame(width: 500, height: 450)
    }
}

struct GettingStartedTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome to RantToMe")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("RantToMe is a macOS menu bar app for speech-to-text transcription. All processing happens entirely on your device - your audio never leaves your Mac.")
                    .foregroundStyle(.secondary)

                Divider()

                HelpSection(title: "First Launch", icon: "arrow.down.circle") {
                    Text("On first launch, you'll need to download a speech recognition model. The app will prompt you to do this automatically. Model sizes range from ~200 MB to ~950 MB depending on your selection.")
                }

                HelpSection(title: "Basic Workflow", icon: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 8) {
                        HelpStep(number: 1, text: "Press the global hotkey (default: Cmd+D) or click the record button")
                        HelpStep(number: 2, text: "Speak your message")
                        HelpStep(number: 3, text: "Press the hotkey again to stop recording")
                        HelpStep(number: 4, text: "The transcription is automatically copied to your clipboard")
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct RecordingTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recording Audio")
                    .font(.title2)
                    .fontWeight(.semibold)

                HelpSection(title: "Global Hotkey", icon: "command") {
                    Text("Press the global hotkey (default: Cmd+D) from anywhere on your Mac to start or stop recording. You can customize this shortcut in Settings.")
                }

                HelpSection(title: "Menu Bar", icon: "menubar.rectangle") {
                    Text("Click the menu bar icon and select \"Start Recording\" to begin. The icon changes to indicate recording status.")
                }

                HelpSection(title: "Floating Window", icon: "rectangle.on.rectangle") {
                    Text("A small floating window shows visual feedback during recording. You can show or hide it from the menu bar dropdown.")
                }

                HelpSection(title: "Minimum Duration", icon: "timer") {
                    Text("Recordings are padded to at least 1 second if needed for reliable transcription.")
                }

                HelpSection(title: "Audio Files", icon: "doc.badge.plus") {
                    Text("You can drag and drop audio files onto the floating window to transcribe existing recordings. In the full window, click the + button in the upper right corner to reveal the drop zone.")
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct ModelsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Speech Recognition Models")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Choose the model that best fits your needs. You can switch models in Settings.")
                    .foregroundStyle(.secondary)

                Divider()

                ModelCard(
                    name: "Parakeet v2 (English)",
                    size: "~900 MB",
                    description: "Fast English transcription with high accuracy. Best choice for English-only use cases.",
                    languages: "English only",
                    speed: "Fastest"
                )

                ModelCard(
                    name: "Parakeet v3 (Multilingual)",
                    size: "~900 MB",
                    description: "Supports 25 European languages with excellent accuracy.",
                    languages: "25 European languages",
                    speed: "Fast"
                )

                ModelCard(
                    name: "Whisper v3 Turbo",
                    size: "~950 MB",
                    description: "Broadest language support with over 100 languages. Best for multilingual or non-European language needs.",
                    languages: "100+ languages",
                    speed: "Moderate"
                )

                Spacer()
            }
            .padding()
        }
    }
}

struct FeaturesTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Features")
                    .font(.title2)
                    .fontWeight(.semibold)

                HelpSection(title: "Auto-Copy to Clipboard", icon: "doc.on.clipboard") {
                    Text("When enabled, transcriptions are automatically copied to your clipboard. Toggle this in the menu bar dropdown or Settings.")
                }

                HelpSection(title: "Transcription History", icon: "clock") {
                    Text("View past transcriptions by selecting \"Show Full Window\" from the menu bar. You can search, copy, and delete entries.")
                }

                HelpSection(title: "Glossary", icon: "text.badge.plus") {
                    Text("Define text replacements to correct common transcription errors or expand abbreviations. For example, replace \"gonna\" with \"going to\". Configure in Settings > Glossary.")
                }

                HelpSection(title: "Sound Feedback", icon: "speaker.wave.2") {
                    Text("Audio cues indicate when recording starts, stops, and when transcription completes. Customize sounds in Settings.")
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct TipsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tips & Privacy")
                    .font(.title2)
                    .fontWeight(.semibold)

                HelpSection(title: "Privacy First", icon: "lock.shield") {
                    Text("All transcription happens on your device. Your audio is never sent to any server or cloud service. Models run locally using your Mac's Neural Engine.")
                }

                HelpSection(title: "Model Caching", icon: "internaldrive") {
                    Text("Models are downloaded once and cached locally. After the initial download, the app works completely offline.")
                }

                HelpSection(title: "Storage Management", icon: "folder") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clear transcription history in Settings > General.")
                        Text("Clear model cache in Settings > Storage (requires re-download).")
                    }
                }

                HelpSection(title: "Best Results", icon: "wand.and.stars") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speak clearly at a normal pace.")
                        Text("Reduce background noise when possible.")
                        Text("Use the glossary to correct recurring errors.")
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Helper Views

struct HelpSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
    }
}

struct HelpStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.medium)
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
    }
}

struct ModelCard: View {
    let name: String
    let size: String
    let description: String
    let languages: String
    let speed: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Text(size)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(languages, systemImage: "globe")
                Label(speed, systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
