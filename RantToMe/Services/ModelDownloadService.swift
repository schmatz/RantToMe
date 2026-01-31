//
//  ModelDownloadService.swift
//  RantToMe
//
//  Secure model download service with revision pinning and hash verification.
//

import CryptoKit
import Foundation

/// Errors that can occur during model download and verification
enum ModelDownloadError: LocalizedError {
    case hashMismatch(expected: String, actual: String, file: String)
    case downloadFailed(String)
    case invalidResponse
    case verificationFailed(String)
    case missingFiles([String])

    var errorDescription: String? {
        switch self {
        case .hashMismatch(let expected, let actual, let file):
            return "Model verification failed for \(file): expected hash \(expected.prefix(16))..., got \(actual.prefix(16))..."
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .verificationFailed(let message):
            return "Verification failed: \(message)"
        case .missingFiles(let files):
            return "Missing required files: \(files.joined(separator: ", "))"
        }
    }
}

/// Configuration for a model to be downloaded
struct ModelDownloadConfig {
    let repository: String
    let revision: String
    let requiredFiles: [String]
    /// SHA256 hash of a manifest file (sorted list of files + their sizes) for verification
    let manifestHash: String?
    /// Individual file hashes for critical files (optional additional verification)
    let fileHashes: [String: String]

    var repoName: String {
        repository.components(separatedBy: "/").last ?? repository
    }
}

/// Pinned model versions with security hashes
///
/// To update these values:
/// 1. Download the model at the new revision
/// 2. Compute the manifest hash using `computeManifestHash(at:)`
/// 3. Update the revision and manifestHash values
/// 4. Test the download flow
enum PinnedModelVersions {
    // MARK: - Parakeet v2 (English)
    // Revision pinned: 2025-01-28
    static let parakeetV2 = ModelDownloadConfig(
        repository: "FluidInference/parakeet-tdt-0.6b-v2-coreml",
        revision: "ee09c569f73759e6d44c9bd16766f477b2b36d39",
        requiredFiles: [
            "Decoder.mlmodelc",
            "Encoder.mlmodelc",
            "JointDecision.mlmodelc",
            "Preprocessor.mlmodelc",
            "parakeet_vocab.json"
        ],
        manifestHash: nil,
        fileHashes: [
            // LFS file hashes (SHA256) pinned from HuggingFace
            "Decoder.mlmodelc/coremldata.bin": "d200ca07694a347f6d02a3886a062ae839831e094e443222f2e48a14945966a8",
            "Encoder.mlmodelc/coremldata.bin": "4def7aa848599ad0e17a8b9a982edcdbf33cf92e1f4b798de32e2ca0bc74b030",
            "Encoder.mlmodelc/weights/weight.bin": "4adc7ad44f9d05e1bffeb2b06d3bb02861a5c7602dff63a6b494aed3bf8a6c3e",
            "JointDecision.mlmodelc/coremldata.bin": "e2c6752f1c8cf2d3f6f26ec93195c9bfa759ad59edf9f806696a138154f96f11",
            "Preprocessor.mlmodelc/coremldata.bin": "d88ea1fc349459c9e100d6a96688c5b29a1f0d865f544be103001724b986b6d6"
        ]
    )

    // MARK: - Parakeet v3 (Multilingual)
    // Revision pinned: 2025-01-28
    static let parakeetV3 = ModelDownloadConfig(
        repository: "FluidInference/parakeet-tdt-0.6b-v3-coreml",
        revision: "dc730587467ddc9f7ea93b6e3ad5caef8b4222f4",
        requiredFiles: [
            "Decoder.mlmodelc",
            "Encoder.mlmodelc",
            "JointDecision.mlmodelc",
            "Preprocessor.mlmodelc",
            "parakeet_vocab.json"
        ],
        manifestHash: nil,
        fileHashes: [
            // LFS file hashes (SHA256) pinned from HuggingFace
            "Decoder.mlmodelc/coremldata.bin": "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99",
            "Encoder.mlmodelc/coremldata.bin": "d48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86",
            "Encoder.mlmodelc/weights/weight.bin": "e2020f323703477a5b21d7c2d282c403e371afb5962e79877e3033e73ba6f421",
            "JointDecision.mlmodelc/coremldata.bin": "f56ded0404498e666ffcd84dda0c393924fc3581345ad03e41429ff560cb97b6",
            "Preprocessor.mlmodelc/coremldata.bin": "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d"
        ]
    )

    // MARK: - Whisper v3 Turbo
    // Revision pinned: 2025-01-28
    static let whisperV3Turbo = ModelDownloadConfig(
        repository: "argmaxinc/whisperkit-coreml",
        revision: "1f92e0a7895c30ff3448ec31a65eb4acffcfd7de",
        requiredFiles: [
            "openai_whisper-large-v3_turbo_954MB"
        ],
        manifestHash: nil,
        fileHashes: [
            // LFS file hashes (SHA256) pinned from HuggingFace
            "openai_whisper-large-v3_turbo_954MB/AudioEncoder.mlmodelc/coremldata.bin": "63b4db8a854c7a64a10b0a0b97048d6d8ee557536367f44dc9fb95fad4bffcf6",
            "openai_whisper-large-v3_turbo_954MB/AudioEncoder.mlmodelc/weights/weight.bin": "3c844b37855e47858a41d36ff89f6c6b39352e2455ea1a836b9f3d327113b1e9",
            "openai_whisper-large-v3_turbo_954MB/MelSpectrogram.mlmodelc/coremldata.bin": "a888718e98af679eee42db9e3609627472c32f77e4fdda28f3735960cbf526b3",
            "openai_whisper-large-v3_turbo_954MB/TextDecoder.mlmodelc/coremldata.bin": "481a53117fe757fd91e9d754ff31e4a0631a8baaef2f8b9ef91832e840974332",
            "openai_whisper-large-v3_turbo_954MB/TextDecoder.mlmodelc/weights/weight.bin": "2cfb2d5996273fada9ecac14219766a3b5d1c3b0f0f13039c2bc177cbef18eeb",
            "openai_whisper-large-v3_turbo_954MB/TextDecoderContextPrefill.mlmodelc/coremldata.bin": "a91550bdd77216fd43a9b00251b6b5aebbcb2a2eee5ca92b2b3cdd0b8aa75971",
            "openai_whisper-large-v3_turbo_954MB/TextDecoderContextPrefill.mlmodelc/weights/weight.bin": "8eab25e68c8eab6f023e2dd2964794c2133fe4af042978e6fbd2b3c8a0f6714e"
        ]
    )
}

/// Helper class for tracking download progress via URLSessionDownloadDelegate
private class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Int64, Int64) -> Void)?
    var continuation: CheckedContinuation<URL, Error>?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onProgress?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Copy to a temporary location we control (the original will be deleted)
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: location, to: tempFile)
            continuation?.resume(returning: tempFile)
        } catch {
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
        }
    }
}

/// Service for securely downloading and verifying ML models from HuggingFace
actor ModelDownloadService {
    private let baseURL = "https://huggingface.co"
    private let fileManager = FileManager.default
    private let downloadDelegate = DownloadProgressDelegate()

    // Sessions are recreated on demand after invalidation
    private var _session: URLSession?
    private var _progressSession: URLSession?

    private var session: URLSession {
        if let existing = _session { return existing }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 1800
        let newSession = URLSession(configuration: config)
        _session = newSession
        return newSession
    }

    private var progressSession: URLSession {
        if let existing = _progressSession { return existing }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 1800
        let newSession = URLSession(configuration: config, delegate: downloadDelegate, delegateQueue: nil)
        _progressSession = newSession
        return newSession
    }

    /// Directory where models are cached
    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("RantToMe/Models")
    }

    init() {
        // Sessions created lazily on first use
    }

    /// Closes all network connections by invalidating sessions
    private func closeConnections() {
        _session?.finishTasksAndInvalidate()
        _session = nil
        _progressSession?.finishTasksAndInvalidate()
        _progressSession = nil
    }

    // MARK: - Public API

    /// Downloads and verifies a model, returning the path to the model directory
    func downloadModel(
        config: ModelDownloadConfig,
        onProgress: @escaping (Double, String) -> Void
    ) async throws -> URL {
        let modelDir = cacheDirectory
            .appendingPathComponent(config.repository.replacingOccurrences(of: "/", with: "_"))
            .appendingPathComponent(config.revision)

        // Check if already downloaded and verified
        if isModelVerified(at: modelDir, config: config) {
            onProgress(1.0, "Model already cached")
            return modelDir
        }

        // Create directory
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

        onProgress(0.0, "Fetching file list...")

        // Get list of files to download
        let files = try await listRepositoryFiles(config: config)

        // Calculate total bytes for progress tracking
        let totalBytes = files.reduce(0) { $0 + ($1.lfs?.size ?? $1.size ?? 1000) }
        var downloadedBytes = 0

        for file in files {
            let fileName = file.path.components(separatedBy: "/").last ?? file.path
            let fileSize = file.lfs?.size ?? file.size ?? 1000
            let startBytes = downloadedBytes

            try await downloadFileWithProgress(
                file: file,
                to: modelDir,
                config: config,
                onProgress: { bytesWritten, totalFileBytes in
                    // Calculate overall progress including partial file progress
                    let fileProgress = totalFileBytes > 0 ? Double(bytesWritten) / Double(totalFileBytes) : 0
                    let currentBytes = startBytes + Int(Double(fileSize) * fileProgress)
                    let overallProgress = Double(currentBytes) / Double(totalBytes)
                    onProgress(overallProgress, "Downloading \(fileName)...")
                }
            )

            downloadedBytes += fileSize
        }

        onProgress(0.95, "Verifying model integrity...")

        // Verify the downloaded model
        try verifyModel(at: modelDir, config: config)

        // Mark as verified
        try markModelVerified(at: modelDir, config: config)

        onProgress(1.0, "Download complete")

        // Close connections to free resources
        closeConnections()

        return modelDir
    }

    /// Checks if a model exists and is verified
    func isModelCached(config: ModelDownloadConfig) -> Bool {
        let modelDir = cacheDirectory
            .appendingPathComponent(config.repository.replacingOccurrences(of: "/", with: "_"))
            .appendingPathComponent(config.revision)
        return isModelVerified(at: modelDir, config: config)
    }

    /// Clears the model cache
    func clearCache() throws {
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.removeItem(at: cacheDirectory)
        }
    }

    /// Computes the manifest hash for a downloaded model (for setting up new versions)
    func computeManifestHash(at directory: URL) throws -> String {
        var manifest = [String]()

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            let size = resourceValues.fileSize ?? 0
            manifest.append("\(relativePath):\(size)")
        }

        manifest.sort()
        let manifestString = manifest.joined(separator: "\n")
        let hash = SHA256.hash(data: Data(manifestString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private Methods

    private struct HFFile: Decodable {
        let path: String
        let type: String
        let size: Int?
        let lfs: LFSInfo?

        struct LFSInfo: Decodable {
            let size: Int
            let oid: String  // HuggingFace API returns SHA256 hash as "oid"

            // Convenience accessor for clarity
            var sha256: String { oid }
        }

        var isDirectory: Bool { type == "directory" }
    }

    private func listRepositoryFiles(config: ModelDownloadConfig) async throws -> [HFFile] {
        var allFiles = [HFFile]()

        // For each required file/directory, get the file list
        for required in config.requiredFiles {
            let files = try await listPath(path: required, config: config)
            allFiles.append(contentsOf: files)
        }

        return allFiles
    }

    private func listPath(path: String, config: ModelDownloadConfig) async throws -> [HFFile] {
        let apiURL = URL(string: "\(baseURL)/api/models/\(config.repository)/tree/\(config.revision)/\(path)")!

        let (data, response) = try await session.data(from: apiURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDownloadError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            // Path is a file, not a directory
            return [HFFile(path: path, type: "file", size: nil, lfs: nil)]
        }

        guard httpResponse.statusCode == 200 else {
            throw ModelDownloadError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let files = try decoder.decode([HFFile].self, from: data)

        var result = [HFFile]()
        for file in files {
            // HuggingFace API returns full paths relative to repo root
            // e.g., listing "Decoder.mlmodelc" returns paths like "Decoder.mlmodelc/analytics"
            if file.isDirectory {
                // Recursively list directory contents
                let subFiles = try await listPath(path: file.path, config: config)
                result.append(contentsOf: subFiles)
            } else {
                result.append(file)
            }
        }

        return result
    }

    private func downloadFileWithProgress(
        file: HFFile,
        to directory: URL,
        config: ModelDownloadConfig,
        onProgress: @escaping (Int64, Int64) -> Void
    ) async throws {
        let fileURL = directory.appendingPathComponent(file.path)
        let parentDir = fileURL.deletingLastPathComponent()

        // Create parent directories if needed
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Skip if file already exists with correct size
        if fileManager.fileExists(atPath: fileURL.path) {
            if let expectedSize = file.size ?? file.lfs?.size {
                let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let actualSize = attrs[.size] as? Int, actualSize == expectedSize {
                    onProgress(Int64(actualSize), Int64(actualSize)) // Report as complete
                    return // File already downloaded correctly
                }
            }
        }

        let downloadURL = URL(string: "\(baseURL)/\(config.repository)/resolve/\(config.revision)/\(file.path)")!

        // Set up progress callback
        downloadDelegate.onProgress = onProgress

        // Download with progress tracking using continuation
        let tempURL: URL = try await withCheckedThrowingContinuation { continuation in
            downloadDelegate.continuation = continuation
            let task = progressSession.downloadTask(with: downloadURL)
            task.resume()
        }

        // Move to final location
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try fileManager.moveItem(at: tempURL, to: fileURL)

        // Verify LFS hash if available
        if let lfs = file.lfs {
            let actualHash = try computeFileHash(at: fileURL)
            if actualHash != lfs.sha256 {
                try fileManager.removeItem(at: fileURL)
                throw ModelDownloadError.hashMismatch(expected: lfs.sha256, actual: actualHash, file: file.path)
            }
        }
    }

    private func computeFileHash(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024) {
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func verifyModel(at directory: URL, config: ModelDownloadConfig) throws {
        // Check required files exist
        var missingFiles = [String]()
        for required in config.requiredFiles {
            let path = directory.appendingPathComponent(required)
            if !fileManager.fileExists(atPath: path.path) {
                missingFiles.append(required)
            }
        }

        if !missingFiles.isEmpty {
            throw ModelDownloadError.missingFiles(missingFiles)
        }

        // Verify manifest hash if provided
        if let expectedHash = config.manifestHash {
            let actualHash = try computeManifestHash(at: directory)
            if actualHash != expectedHash {
                throw ModelDownloadError.hashMismatch(expected: expectedHash, actual: actualHash, file: "manifest")
            }
        }

        // Verify individual file hashes if provided
        for (filePath, expectedHash) in config.fileHashes {
            let fileURL = directory.appendingPathComponent(filePath)
            let actualHash = try computeFileHash(at: fileURL)
            if actualHash != expectedHash {
                throw ModelDownloadError.hashMismatch(expected: expectedHash, actual: actualHash, file: filePath)
            }
        }
    }

    private var verificationMarkerName: String { ".verified" }

    private func isModelVerified(at directory: URL, config: ModelDownloadConfig) -> Bool {
        let markerPath = directory.appendingPathComponent(verificationMarkerName)
        guard fileManager.fileExists(atPath: markerPath.path) else { return false }

        // Check marker contains correct revision
        guard let contents = try? String(contentsOf: markerPath, encoding: .utf8) else { return false }
        return contents.trimmingCharacters(in: .whitespacesAndNewlines) == config.revision
    }

    private func markModelVerified(at directory: URL, config: ModelDownloadConfig) throws {
        let markerPath = directory.appendingPathComponent(verificationMarkerName)
        try config.revision.write(to: markerPath, atomically: true, encoding: .utf8)
    }
}
