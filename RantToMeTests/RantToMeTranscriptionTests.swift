//
//  RantToMeTests.swift
//  RantToMeTests
//
//  Created by Michael Schmatz on 1/16/26.
//

import Testing
import FluidAudio
import WhisperKit
import Foundation
@testable import RantToMe

// Force serial execution to avoid concurrent model loading
@Suite(.serialized)
struct RantToMeTests {

    // MARK: - FluidAudio (Parakeet) Tests

    @Test func loadFluidAudioParakeetV2() async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v2)
        let asrManager = AsrManager(config: .default)
        try await asrManager.initialize(models: models)
        print("Successfully loaded Parakeet TDT v2 model!")
    }

    @Test func loadFluidAudioParakeetV3() async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let asrManager = AsrManager(config: .default)
        try await asrManager.initialize(models: models)
        print("Successfully loaded Parakeet TDT v3 model!")
    }

    // MARK: - WhisperKit Tests

    @Test func loadWhisperKitLargeV3Turbo() async throws {
        let config = WhisperKitConfig(
            model: "openai_whisper-large-v3_turbo_954MB",
            verbose: true,
            logLevel: .debug,
            prewarm: false,
            load: true
        )

        let whisperKit = try await WhisperKit(config)
        #expect(whisperKit != nil)
        print("Successfully loaded Whisper large-v3-turbo model!")
    }
}
