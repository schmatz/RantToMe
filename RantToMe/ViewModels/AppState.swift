//
//  AppState.swift
//  RantToMe
//

import AppKit
import Foundation
import os.log
import UserNotifications

private let logger = Logger(subsystem: "com.rantto.me", category: "AppState")

extension Notification.Name {
    static let openFullWindow = Notification.Name("openFullWindow")
}

enum AppMode: Equatable {
    case downloadRequired
    case loadingModel
    case ready
    case recording
    case transcribing
}

@MainActor
@Observable
final class AppState {
    private(set) var mode: AppMode = .downloadRequired
    private(set) var history: [TranscriptionEntry] = []
    private(set) var errorMessage: String?
    private(set) var modelLoadProgress: Double = 0
    private(set) var modelLoadStatus: String = "Preparing..."
    /// Set to true when main window should be shown (e.g., on error)
    var shouldShowMainWindow: Bool = false
    private(set) var modelLoadStartTime: Date?
    private(set) var transcriptionProgress: Double = 0
    private var transcriptionStartTime: Date?
    private var recordingStartTime: Date?

    var isFloatingWindowVisible: Bool = true

    var autoCopyEnabled: Bool = true {
        didSet { UserDefaults.standard.set(autoCopyEnabled, forKey: "autoCopyEnabled") }
    }

    var autoPasteEnabled: Bool = false {
        didSet { UserDefaults.standard.set(autoPasteEnabled, forKey: "autoPasteEnabled") }
    }

    var fnKeyRecordingEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(fnKeyRecordingEnabled, forKey: "fnKeyRecordingEnabled")
            updateFnKeyRecordingService()
        }
    }

    var soundsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled") }
    }

    static let availableSounds = [
        "None", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    var recordingStartSound: String = "Pop" {
        didSet { UserDefaults.standard.set(recordingStartSound, forKey: "recordingStartSound") }
    }

    var recordingStopSound: String = "None" {
        didSet { UserDefaults.standard.set(recordingStopSound, forKey: "recordingStopSound") }
    }

    var transcriptionCompleteSound: String = "Blow" {
        didSet { UserDefaults.standard.set(transcriptionCompleteSound, forKey: "transcriptionCompleteSound") }
    }

    var selectedModelVersion: AppModelVersion = .parakeetV2 {
        didSet {
            UserDefaults.standard.set(selectedModelVersion.rawValue, forKey: "selectedModelVersion")
        }
    }

    var frogeModeEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(frogeModeEnabled, forKey: "frogeModeEnabled")
        }
    }

    var historyLoggingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "historyLoggingEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "historyLoggingEnabled") }
    }

    // MARK: - LLM Cleanup Settings

    var llmCleanupEnabled: Bool = false {
        didSet { UserDefaults.standard.set(llmCleanupEnabled, forKey: "llmCleanupEnabled") }
    }

    var llmCleanupModel: LLMModel = .haiku {
        didSet { UserDefaults.standard.set(llmCleanupModel.rawValue, forKey: "llmCleanupModel") }
    }

    static let defaultLLMCleanupPrompt = ""

    var llmCleanupPrompt: String = AppState.defaultLLMCleanupPrompt {
        didSet { UserDefaults.standard.set(llmCleanupPrompt, forKey: "llmCleanupPrompt") }
    }

    var llmCleanupThinkingEnabled: Bool = false {
        didSet { UserDefaults.standard.set(llmCleanupThinkingEnabled, forKey: "llmCleanupThinkingEnabled") }
    }

    private(set) var transientWarning: String?
    private var warningDismissTask: Task<Void, Never>?

    private static func loadSelectedModelVersion() -> AppModelVersion {
        // Migration: old "v2"/"v3" values map to new parakeet values
        let stored = UserDefaults.standard.string(forKey: "selectedModelVersion") ?? "parakeet_v2"
        if let version = AppModelVersion(rawValue: stored) {
            return version
        }
        // Handle old format
        switch stored {
        case "v2": return .parakeetV2
        case "v3": return .parakeetV3
        default: return .parakeetV2
        }
    }

    func playSound(_ name: String) {
        guard name != "None" else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: - Easter Egg Detection

    private func checkForEasterEgg(in text: String) {
        let normalizedText = text.lowercased()

        // Quick check: only run expensive fuzzy matching if key words are present
        let hasSummon = normalizedText.contains("summon")
        let hasExile = normalizedText.contains("exile")
        guard hasSummon || hasExile else { return }

        let summonPhrase = "i hereby summon my companion the froge"
        let exilePhrase = "i hereby exile my companion the froge"

        // Length check: text should be approximately the same length as the phrase
        let maxLength = summonPhrase.count + 20  // Allow some extra characters
        guard normalizedText.count <= maxLength else { return }

        // Find the best match distance for each phrase
        let summonDistance = hasSummon ? bestMatchDistance(normalizedText, phrase: summonPhrase) : Int.max
        let exileDistance = hasExile ? bestMatchDistance(normalizedText, phrase: exilePhrase) : Int.max

        // Only trigger if one phrase is clearly a better match than the other
        let maxDistance = 5
        if summonDistance <= maxDistance && summonDistance < exileDistance {
            frogeModeEnabled = true
        } else if exileDistance <= maxDistance && exileDistance < summonDistance {
            frogeModeEnabled = false
        }
    }

    private func bestMatchDistance(_ text: String, phrase: String) -> Int {
        let phraseLength = phrase.count
        guard text.count >= phraseLength else {
            return levenshteinDistance(text, phrase)
        }

        var bestDistance = Int.max
        let textChars = Array(text)

        // Check exact-length windows
        for i in 0...(textChars.count - phraseLength) {
            let window = String(textChars[i..<(i + phraseLength)])
            let distance = levenshteinDistance(window, phrase)
            bestDistance = min(bestDistance, distance)
        }

        // Also check slightly larger windows to account for extra words
        let extendedLength = min(phraseLength + 10, textChars.count)
        if extendedLength > phraseLength {
            for i in 0...(textChars.count - extendedLength) {
                let window = String(textChars[i..<(i + extendedLength)])
                let distance = levenshteinDistance(window, phrase)
                bestDistance = min(bestDistance, distance)
            }
        }

        return bestDistance
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Chars = Array(s1)
        let s2Chars = Array(s2)
        let m = s1Chars.count
        let n = s2Chars.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Chars[i - 1] == s2Chars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    var showClearCacheButton: Bool {
        guard let startTime = modelLoadStartTime, mode == .loadingModel else { return false }
        return Date().timeIntervalSince(startTime) > 30
    }

    var selectedEntryIDs: Set<UUID> = []

    var selectedEntries: [TranscriptionEntry] {
        history.filter { selectedEntryIDs.contains($0.id) }
    }

    var singleSelectedEntry: TranscriptionEntry? {
        guard selectedEntryIDs.count == 1,
              let id = selectedEntryIDs.first else { return nil }
        return history.first { $0.id == id }
    }

    var totalLLMCleanupCost: Double {
        history.compactMap(\.llmCleanupCost).reduce(0, +)
    }

    let audioRecorder = AudioRecorder()
    let glossaryManager = GlossaryManager()
    private var transcriptionService: TranscriptionService?
    private var fnKeyRecordingService: FnKeyRecordingService?
    private let llmCleanupService = LLMCleanupService()

    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("RantToMe")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("transcription_history.json")
    }

    init() {
        UserDefaults.standard.register(defaults: [
            "autoCopyEnabled": true,
            "autoPasteEnabled": false,
            "fnKeyRecordingEnabled": false,
            "soundsEnabled": true,
            "recordingStartSound": "Pop",
            "recordingStopSound": "None",
            "transcriptionCompleteSound": "Blow",
            "historyLoggingEnabled": true,
            "llmCleanupEnabled": false,
            "llmCleanupPrompt": AppState.defaultLLMCleanupPrompt,
            "llmCleanupThinkingEnabled": false
        ])

        // Load settings from UserDefaults
        autoCopyEnabled = UserDefaults.standard.bool(forKey: "autoCopyEnabled")
        autoPasteEnabled = UserDefaults.standard.bool(forKey: "autoPasteEnabled")
        fnKeyRecordingEnabled = UserDefaults.standard.bool(forKey: "fnKeyRecordingEnabled")
        soundsEnabled = UserDefaults.standard.bool(forKey: "soundsEnabled")
        recordingStartSound = UserDefaults.standard.string(forKey: "recordingStartSound") ?? "Pop"
        recordingStopSound = UserDefaults.standard.string(forKey: "recordingStopSound") ?? "None"
        transcriptionCompleteSound = UserDefaults.standard.string(forKey: "transcriptionCompleteSound") ?? "Blow"

        // Load model selection from UserDefaults
        selectedModelVersion = Self.loadSelectedModelVersion()

        // Load appearance setting from UserDefaults
        frogeModeEnabled = UserDefaults.standard.bool(forKey: "frogeModeEnabled")

        // Load LLM cleanup settings
        llmCleanupEnabled = UserDefaults.standard.bool(forKey: "llmCleanupEnabled")
        if let modelRaw = UserDefaults.standard.string(forKey: "llmCleanupModel"),
           let model = LLMModel(rawValue: modelRaw) {
            llmCleanupModel = model
        }
        llmCleanupPrompt = UserDefaults.standard.string(forKey: "llmCleanupPrompt") ?? AppState.defaultLLMCleanupPrompt
        llmCleanupThinkingEnabled = UserDefaults.standard.bool(forKey: "llmCleanupThinkingEnabled")

        transcriptionService = TranscriptionService()
        loadHistory()
        checkModelAvailability()
        requestNotificationPermission()
        updateFnKeyRecordingService()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showTranscriptionCompleteNotification(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Complete"
        content.body = String(text.prefix(100)) + (text.count > 100 ? "..." : "")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func checkModelAvailability() {
        // FluidAudio manages its own model downloads, so always try to load
        mode = .loadingModel
        Task {
            await loadModel()
        }
    }

    func downloadModel() async {
        await loadModel()
    }

    private func loadModel() async {
        mode = .loadingModel
        modelLoadProgress = 0
        modelLoadStatus = "Preparing..."
        modelLoadStartTime = Date()

        do {
            try await transcriptionService?.loadModel(version: selectedModelVersion) { [weak self] progress, status in
                Task { @MainActor in
                    self?.modelLoadProgress = progress
                    self?.modelLoadStatus = status
                }
            }
            mode = .ready
        } catch let error as ModelDownloadError {
            // Provide specific guidance for model verification failures
            switch error {
            case .hashMismatch:
                errorMessage = "Model verification failed. The downloaded model may be corrupted or tampered with. Please clear the model cache in Settings and try again."
            case .missingFiles:
                errorMessage = "Model download incomplete. Please clear the model cache in Settings and try again."
            default:
                errorMessage = "Failed to load model: \(error.localizedDescription)"
            }
            mode = .downloadRequired
            shouldShowMainWindow = true
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            mode = .downloadRequired
            shouldShowMainWindow = true
        }
    }

    func reloadModelIfNeeded() async {
        guard transcriptionService?.currentModelVersion != selectedModelVersion else { return }
        await loadModel()
    }

    func toggleRecording() async {
        let toggleStart = CFAbsoluteTimeGetCurrent()
        let screenCount = NSScreen.screens.count
        let mainScreenFrame = NSScreen.main?.frame ?? .zero
        logger.info("⏱️ toggleRecording() called, mode=\(String(describing: self.mode)), isRecording=\(self.audioRecorder.isRecording), screens=\(screenCount), mainScreen=\(mainScreenFrame.width)x\(mainScreenFrame.height)")

        // Ignore hotkey if model isn't ready
        guard mode == .ready || mode == .recording else {
            logger.info("⏱️ toggleRecording() ignored - mode not ready/recording")
            return
        }

        if audioRecorder.isRecording {
            logger.info("⏱️ toggleRecording() calling stopRecordingAndTranscribe, elapsed=\((CFAbsoluteTimeGetCurrent() - toggleStart) * 1000)ms")
            await stopRecordingAndTranscribe()
        } else {
            await startRecording()
        }
        logger.info("⏱️ toggleRecording() complete, total elapsed=\((CFAbsoluteTimeGetCurrent() - toggleStart) * 1000)ms")
    }

    private func startRecording() async {
        await audioRecorder.checkPermission()
        if audioRecorder.permissionDenied {
            errorMessage = "Microphone access is required. Please enable it in System Settings > Privacy & Security > Microphone."
            return
        }

        do {
            try audioRecorder.startRecording()
            mode = .recording
            recordingStartTime = Date()
            if soundsEnabled {
                playSound(recordingStartSound)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecordingAndTranscribe() async {
        let funcStart = CFAbsoluteTimeGetCurrent()
        logger.info("⏱️ stopRecordingAndTranscribe() START")

        // Ensure at least 1 second of recording to satisfy ASR minimum requirements
        if let startTime = recordingStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumDuration: TimeInterval = 1.0
            if elapsed < minimumDuration {
                let sleepTime = minimumDuration - elapsed
                logger.info("⏱️ Sleeping for minimum duration: \(sleepTime)s")
                try? await Task.sleep(for: .seconds(sleepTime))
                logger.info("⏱️ Sleep complete, elapsed=\((CFAbsoluteTimeGetCurrent() - funcStart) * 1000)ms")
            }
        }

        logger.info("⏱️ Calling audioRecorder.stopRecording(), elapsed=\((CFAbsoluteTimeGetCurrent() - funcStart) * 1000)ms")
        let stopStart = CFAbsoluteTimeGetCurrent()
        guard let url = audioRecorder.stopRecording() else {
            logger.error("⏱️ audioRecorder.stopRecording() returned nil!")
            return
        }
        logger.info("⏱️ audioRecorder.stopRecording() took \((CFAbsoluteTimeGetCurrent() - stopStart) * 1000)ms")

        recordingStartTime = nil
        logger.info("⏱️ Setting mode = .transcribing, elapsed=\((CFAbsoluteTimeGetCurrent() - funcStart) * 1000)ms")
        mode = .transcribing
        logger.info("⏱️ Mode set to .transcribing, elapsed=\((CFAbsoluteTimeGetCurrent() - funcStart) * 1000)ms")

        if soundsEnabled {
            playSound(recordingStopSound)
        }
        transcriptionProgress = 0
        transcriptionStartTime = Date()

        logger.info("⏱️ Starting transcription, elapsed=\((CFAbsoluteTimeGetCurrent() - funcStart) * 1000)ms")
        do {
            let transcribeStart = CFAbsoluteTimeGetCurrent()
            let text = try await transcriptionService?.transcribe(audioURL: url) { [weak self] progress in
                Task { @MainActor in
                    self?.transcriptionProgress = progress
                }
            } ?? ""
            logger.info("⏱️ Transcription complete, took \((CFAbsoluteTimeGetCurrent() - transcribeStart) * 1000)ms")
            let glossaryProcessedText = glossaryManager.applyReplacements(to: text)
            checkForEasterEgg(in: glossaryProcessedText)

            // Apply LLM cleanup if enabled
            let (finalText, originalText, llmApplied, llmCost) = await performLLMCleanupIfEnabled(text: glossaryProcessedText)

            let entry = TranscriptionEntry(
                text: finalText,
                sourceType: .recording,
                originalText: originalText,
                llmCleanupApplied: llmApplied,
                llmCleanupCost: llmCost
            )
            addEntry(entry)
            if autoCopyEnabled {
                copyToClipboard(finalText)
                if autoPasteEnabled {
                    await AutoPasteService.performPaste()
                }
            } else {
                NotificationCenter.default.post(name: .openFullWindow, object: nil)
            }
            if let startTime = transcriptionStartTime,
               Date().timeIntervalSince(startTime) > 60 {
                showTranscriptionCompleteNotification(text: finalText)
            }
            if soundsEnabled {
                playSound(transcriptionCompleteSound)
            }
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
        }

        audioRecorder.cleanupRecording()
        mode = .ready
    }

    func transcribeFile(at url: URL) async {
        mode = .transcribing
        if soundsEnabled {
            playSound(recordingStopSound)
        }
        transcriptionProgress = 0
        transcriptionStartTime = Date()
        errorMessage = nil

        do {
            let text = try await transcriptionService?.transcribe(audioURL: url) { [weak self] progress in
                Task { @MainActor in
                    self?.transcriptionProgress = progress
                }
            } ?? ""
            let glossaryProcessedText = glossaryManager.applyReplacements(to: text)
            checkForEasterEgg(in: glossaryProcessedText)

            // Apply LLM cleanup if enabled
            let (finalText, originalText, llmApplied, llmCost) = await performLLMCleanupIfEnabled(text: glossaryProcessedText)

            let entry = TranscriptionEntry(
                text: finalText,
                sourceType: .file,
                sourceFileName: url.lastPathComponent,
                originalText: originalText,
                llmCleanupApplied: llmApplied,
                llmCleanupCost: llmCost
            )
            addEntry(entry)
            if autoCopyEnabled {
                copyToClipboard(finalText)
                if autoPasteEnabled {
                    await AutoPasteService.performPaste()
                }
            } else {
                NotificationCenter.default.post(name: .openFullWindow, object: nil)
            }
            if let startTime = transcriptionStartTime,
               Date().timeIntervalSince(startTime) > 60 {
                showTranscriptionCompleteNotification(text: finalText)
            }
            if soundsEnabled {
                playSound(transcriptionCompleteSound)
            }
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
        }

        mode = .ready
    }

    private func addEntry(_ entry: TranscriptionEntry) {
        guard historyLoggingEnabled else { return }
        history.insert(entry, at: 0)
        selectedEntryIDs = [entry.id]
        saveHistory()
    }

    func deleteEntries(_ entries: [TranscriptionEntry]) {
        let idsToDelete = Set(entries.map { $0.id })
        history.removeAll { idsToDelete.contains($0.id) }
        selectedEntryIDs.subtract(idsToDelete)
        saveHistory()
    }

    func clearAllHistory() {
        history.removeAll()
        selectedEntryIDs.removeAll()
        saveHistory()
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func loadHistory() {
        // Migrate from old location if needed
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let oldFileURL = appSupport.appendingPathComponent("transcription_history.json")
        if FileManager.default.fileExists(atPath: oldFileURL.path) && !FileManager.default.fileExists(atPath: historyFileURL.path) {
            try? FileManager.default.moveItem(at: oldFileURL, to: historyFileURL)
        }

        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            history = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
        } catch {
            // Start with empty history if loading fails
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL)
        } catch {
            // Silently fail - history will be lost on restart
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func showTransientWarning(_ message: String) {
        transientWarning = message
        warningDismissTask?.cancel()
        warningDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                transientWarning = nil
            }
        }
    }

    func clearTransientWarning() {
        warningDismissTask?.cancel()
        transientWarning = nil
    }

    private func performLLMCleanupIfEnabled(text: String) async -> (cleanedText: String, originalText: String?, llmApplied: Bool, cost: Double?) {
        guard llmCleanupEnabled,
              let apiKey = KeychainService.loadAnthropicAPIKey() else {
            return (text, nil, false, nil)
        }

        let result = await llmCleanupService.cleanup(
            text: text,
            model: llmCleanupModel,
            prompt: llmCleanupPrompt,
            apiKey: apiKey,
            thinkingEnabled: llmCleanupThinkingEnabled
        )

        if let warning = result.warning {
            showTransientWarning(warning)
        }

        if result.usedOriginal {
            return (text, nil, false, nil)
        } else {
            return (result.text, text, true, result.cost)
        }
    }

    // MARK: - Fn Key Recording

    private func updateFnKeyRecordingService() {
        if fnKeyRecordingEnabled {
            if fnKeyRecordingService == nil {
                fnKeyRecordingService = FnKeyRecordingService()
            }
            // The callback is invoked from within a Task { @MainActor in } in FnKeyRecordingService,
            // so we're already on the MainActor when this closure runs.
            _ = fnKeyRecordingService?.start { [weak self] isPressed in
                self?.handleFnKeyStateChanged(isPressed: isPressed)
            }
        } else {
            fnKeyRecordingService?.stop()
            fnKeyRecordingService = nil
        }
    }

    private func handleFnKeyStateChanged(isPressed: Bool) {
        let callbackTime = CFAbsoluteTimeGetCurrent()
        let screenCount = NSScreen.screens.count
        logger.info("⏱️ handleFnKeyStateChanged(isPressed=\(isPressed)) called, mode=\(String(describing: self.mode)), screens=\(screenCount)")

        // Only respond if model is ready or currently recording
        guard mode == .ready || mode == .recording else {
            logger.info("⏱️ handleFnKeyStateChanged ignored - mode not ready/recording")
            return
        }

        // Use a single Task for both operations to reduce async hop overhead.
        // This matches how toggleRecording() works for the global hotkey path.
        Task {
            let taskStart = CFAbsoluteTimeGetCurrent()
            logger.info("⏱️ handleFnKeyStateChanged Task started, delay from callback=\((taskStart - callbackTime) * 1000)ms")

            if isPressed && mode == .ready {
                await startRecording()
            } else if !isPressed && mode == .recording {
                logger.info("⏱️ handleFnKeyStateChanged calling stopRecordingAndTranscribe")
                await stopRecordingAndTranscribe()
            }
            logger.info("⏱️ handleFnKeyStateChanged Task complete, total elapsed=\((CFAbsoluteTimeGetCurrent() - callbackTime) * 1000)ms")
        }
    }

    func clearCacheAndRestart() {
        clearModelCache()

        // Relaunch app using NSWorkspace (works in sandboxed apps)
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Model Cache Management

    private var modelCacheURLs: [URL] {
        let fm = FileManager.default
        var urls: [URL] = []

        // Secure model cache (new location with revision pinning)
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(appSupport.appendingPathComponent("RantToMe/Models"))
        }

        // Legacy: FluidAudio cache in Application Support
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(appSupport.appendingPathComponent("FluidAudio"))
        }

        // Legacy: Hugging Face cache in Library/Caches
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            urls.append(caches.appendingPathComponent("huggingface"))
        }

        // Legacy: Hugging Face cache in home directory (.cache/huggingface)
        let homeCache = fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface")
        urls.append(homeCache)

        // Legacy: WhisperKit cache in Documents/huggingface
        if let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            urls.append(documents.appendingPathComponent("huggingface"))
        }

        return urls
    }

    var modelCacheSize: Int64 {
        let fm = FileManager.default
        var totalSize: Int64 = 0

        for cacheURL in modelCacheURLs {
            guard fm.fileExists(atPath: cacheURL.path) else { continue }
            if let enumerator = fm.enumerator(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
        }

        return totalSize
    }

    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: modelCacheSize)
    }

    func clearModelCache() {
        for cacheURL in modelCacheURLs {
            try? FileManager.default.removeItem(at: cacheURL)
        }
    }
}
