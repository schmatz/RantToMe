//
//  DropZoneView.swift
//  RantToMe
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let isEnabled: Bool
    let onDrop: (URL) -> Void

    @State private var isTargeted = false

    private let supportedTypes: [UTType] = [.audio, .wav, .mp3, .mpeg4Audio, .aiff]

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            .foregroundStyle(isTargeted ? .blue : .secondary.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    Text("Drop audio file here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("WAV, M4A, MP3, AIFF")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 120)
            .onDrop(of: supportedTypes, isTargeted: $isTargeted) { providers in
                guard isEnabled else { return false }

                for provider in providers {
                    for type in supportedTypes {
                        if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                                guard let url = url, error == nil else { return }

                                // Copy to temp location since the provided URL is temporary
                                // Use a unique subdirectory to preserve the original filename
                                let tempDir = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

                                do {
                                    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                                    try FileManager.default.copyItem(at: url, to: tempURL)
                                    Task { @MainActor in
                                        onDrop(tempURL)
                                    }
                                } catch {
                                    // Handle copy error silently
                                }
                            }
                            return true
                        }
                    }
                }
                return false
            }
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}
