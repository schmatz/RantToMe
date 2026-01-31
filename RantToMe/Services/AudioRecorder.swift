//
//  AudioRecorder.swift
//  RantToMe
//

import AVFoundation
import Foundation

@MainActor
@Observable
final class AudioRecorder: NSObject {
    private(set) var isRecording = false
    private(set) var recordingURL: URL?
    private(set) var permissionGranted = false
    private(set) var permissionDenied = false

    private var audioRecorder: AVAudioRecorder?

    private var recordingsDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("Recordings")
    }

    func checkPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            permissionGranted = true
            permissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            permissionGranted = granted
            permissionDenied = !granted
        case .denied, .restricted:
            permissionGranted = false
            permissionDenied = true
        @unknown default:
            permissionGranted = false
            permissionDenied = true
        }
    }

    func startRecording() throws {
        guard permissionGranted else {
            throw RecordingError.permissionDenied
        }

        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)

        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let url = recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()

        recordingURL = url
        isRecording = true
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        return recordingURL
    }

    func cleanupRecording() {
        guard let url = recordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }

    enum RecordingError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission is required to record audio."
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Recording finished
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        // Handle encoding error if needed
    }
}
