//
//  TranscriptionService.swift
//  RantToMe
//

import AVFoundation
import CoreML
import FluidAudio
import Foundation
import WhisperKit

enum AppModelVersion: String, CaseIterable {
    case parakeetV2 = "parakeet_v2"  // English-only, higher recall, fastest
    case parakeetV3 = "parakeet_v3"  // Multilingual (25 European languages)
    case whisperV3Turbo = "whisper_v3_turbo"  // Multilingual (100+ languages), slower

    var displayName: String {
        switch self {
        case .parakeetV2: return "Parakeet v2 (English)"
        case .parakeetV3: return "Parakeet v3 (Multilingual)"
        case .whisperV3Turbo: return "Whisper v3 Turbo (100+ languages)"
        }
    }

    var isParakeet: Bool {
        switch self {
        case .parakeetV2, .parakeetV3: return true
        case .whisperV3Turbo: return false
        }
    }

    var fluidVersion: AsrModelVersion? {
        switch self {
        case .parakeetV2: return .v2
        case .parakeetV3: return .v3
        case .whisperV3Turbo: return nil
        }
    }

    /// Returns the pinned download configuration for this model version
    var downloadConfig: ModelDownloadConfig {
        switch self {
        case .parakeetV2: return PinnedModelVersions.parakeetV2
        case .parakeetV3: return PinnedModelVersions.parakeetV3
        case .whisperV3Turbo: return PinnedModelVersions.whisperV3Turbo
        }
    }
}

@MainActor
final class TranscriptionService {
    // FluidAudio (Parakeet) backend
    private var asrManager: AsrManager?

    // WhisperKit backend
    private var whisperKit: WhisperKit?
    private let whisperModelVariant = "openai_whisper-large-v3_turbo_954MB"

    private var loadedModelVersion: AppModelVersion?

    // Secure model download service with revision pinning and hash verification
    private let downloadService = ModelDownloadService()

    func loadModel(version: AppModelVersion, onProgress: @escaping (Double, String) -> Void) async throws {
        // Unload previous model if switching backends
        if let loaded = loadedModelVersion, loaded.isParakeet != version.isParakeet {
            asrManager = nil
            whisperKit = nil
        }

        if version.isParakeet {
            try await loadParakeetModel(version: version, onProgress: onProgress)
        } else {
            try await loadWhisperModel(onProgress: onProgress)
        }

        loadedModelVersion = version
    }

    private func loadParakeetModel(version: AppModelVersion, onProgress: @escaping (Double, String) -> Void) async throws {
        guard let fluidVersion = version.fluidVersion else {
            throw TranscriptionError.modelNotAvailable
        }

        // Download model using secure service with pinned revision
        let modelDirectory = try await downloadService.downloadModel(
            config: version.downloadConfig,
            onProgress: { progress, status in
                // Download is 0-70% of total progress
                // Force main thread update for UI responsiveness
                Task { @MainActor in
                    onProgress(progress * 0.7, status)
                }
            }
        )

        onProgress(0.7, "Loading model (may take a while on first run)...")

        // Animate progress from 70% to 99% over 2 minutes while model compiles
        let progressTask = Task {
            let startTime = Date()
            let duration: TimeInterval = 60 // 1 minute
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let animatedProgress = min(0.99, 0.7 + (0.29 * elapsed / duration))
                onProgress(animatedProgress, "Loading model (may take a while on first run)...")
                if animatedProgress >= 0.99 { break }
                try? await Task.sleep(nanoseconds: 500_000_000) // Update every 0.5s
            }
        }

        // Load the model from the downloaded directory
        let models = try await AsrModels.load(
            from: modelDirectory,
            configuration: AsrModels.defaultConfiguration(),
            version: fluidVersion
        )

        progressTask.cancel()

        onProgress(0.95, "Initializing ASR engine...")
        asrManager = AsrManager(config: .default)
        try await asrManager?.initialize(models: models)

        onProgress(1.0, "Ready")
    }

    private func loadWhisperModel(onProgress: @escaping (Double, String) -> Void) async throws {
        // Download model using secure service with pinned revision
        let modelDirectory = try await downloadService.downloadModel(
            config: AppModelVersion.whisperV3Turbo.downloadConfig,
            onProgress: { progress, status in
                // Download is 0-70% of total progress
                // Force main thread update for UI responsiveness
                Task { @MainActor in
                    onProgress(progress * 0.7, status)
                }
            }
        )

        onProgress(0.7, "Loading model (may take a while on first run)...")

        // Animate progress from 70% to 99% over 2 minutes while model compiles
        let progressTask = Task {
            let startTime = Date()
            let duration: TimeInterval = 60 // 1 minute
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let animatedProgress = min(0.99, 0.7 + (0.29 * elapsed / duration))
                onProgress(animatedProgress, "Loading model (may take a while on first run)...")
                if animatedProgress >= 0.99 { break }
                try? await Task.sleep(nanoseconds: 500_000_000) // Update every 0.5s
            }
        }

        // The WhisperKit model is inside a subdirectory
        let modelFolder = modelDirectory.appendingPathComponent(whisperModelVariant)

        let config = WhisperKitConfig(
            model: whisperModelVariant,
            modelFolder: modelFolder.path,
            computeOptions: .init(audioEncoderCompute: .cpuAndGPU, textDecoderCompute: .cpuAndGPU),
            verbose: false,
            logLevel: .none,
            prewarm: false,
            load: true,
            download: false
        )

        whisperKit = try await WhisperKit(config)

        progressTask.cancel()
        onProgress(1.0, "Ready")
    }

    func transcribe(audioURL: URL, onProgress: @escaping (Double) -> Void) async throws -> String {
        guard let version = loadedModelVersion else {
            throw TranscriptionError.modelNotLoaded
        }

        if version.isParakeet {
            return try await transcribeWithParakeet(audioURL: audioURL, onProgress: onProgress)
        } else {
            return try await transcribeWithWhisper(audioURL: audioURL, onProgress: onProgress)
        }
    }

    private func transcribeWithParakeet(audioURL: URL, onProgress: @escaping (Double) -> Void) async throws -> String {
        guard let asrManager = asrManager else {
            throw TranscriptionError.modelNotLoaded
        }

        onProgress(0.1)
        let result = try await asrManager.transcribe(audioURL, source: .system)
        onProgress(1.0)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transcribeWithWhisper(audioURL: URL, onProgress: @escaping (Double) -> Void) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let progressTask = Task {
            while !Task.isCancelled {
                let progress = whisperKit.progress.fractionCompleted
                onProgress(progress)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        defer { progressTask.cancel() }

        let results = try await whisperKit.transcribe(audioPath: audioURL.path)
        onProgress(1.0)

        let text = results.map { $0.text }.joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var currentModelVersion: AppModelVersion? {
        loadedModelVersion
    }

    enum TranscriptionError: LocalizedError {
        case modelNotAvailable
        case modelNotLoaded
        case transcriptionFailed
        case modelVerificationFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotAvailable:
                return "Speech model is not available."
            case .modelNotLoaded:
                return "Speech model is not loaded."
            case .transcriptionFailed:
                return "Transcription failed."
            case .modelVerificationFailed(let details):
                return "Model verification failed: \(details). Please clear the model cache and try again."
            }
        }
    }
}
