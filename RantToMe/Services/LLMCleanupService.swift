//
//  LLMCleanupService.swift
//  RantToMe
//

import Foundation
import os.log

enum LLMModel: String, CaseIterable, Codable {
    case haiku = "claude-haiku-4-5-20251001"
    case sonnet = "claude-sonnet-4-5-20250929"
    case opus = "claude-opus-4-5-20251101"

    var displayName: String {
        switch self {
        case .haiku: return "Haiku 4.5 (fastest)"
        case .sonnet: return "Sonnet 4.5 (balanced)"
        case .opus: return "Opus 4.5 (best quality)"
        }
    }

    /// Cost per million input tokens in USD
    var inputCostPerMTok: Double {
        switch self {
        case .haiku: return 1.0
        case .sonnet: return 3.0
        case .opus: return 5.0
        }
    }

    /// Cost per million output tokens in USD
    var outputCostPerMTok: Double {
        switch self {
        case .haiku: return 5.0
        case .sonnet: return 15.0
        case .opus: return 25.0
        }
    }

    func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000.0 * inputCostPerMTok
        let outputCost = Double(outputTokens) / 1_000_000.0 * outputCostPerMTok
        return inputCost + outputCost
    }
}

struct CleanupResult {
    let text: String
    let warning: String?
    let usedOriginal: Bool
    let cost: Double?
    let inputTokens: Int?
    let outputTokens: Int?
}

enum LLMCleanupError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case rateLimited
    case serverError(Int)
    case invalidResponse
    case timeout
    case textTooLong(Int)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited by API"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid response from API"
        case .timeout:
            return "Request timed out"
        case .textTooLong(let count):
            return "Text too long for AI cleanup (\(count) characters)"
        }
    }
}

actor LLMCleanupService {
    private let session: URLSession
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let timeoutInterval: TimeInterval = 30
    private let logger = Logger(subsystem: "com.rantome", category: "LLMCleanup")

    /// Maximum character count for AI cleanup (~3 hours of speech, ~37K tokens)
    /// Beyond this, output token limits become a concern
    static let maxCharacterCount = 150_000

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        self.session = URLSession(configuration: config)
    }

    func cleanup(text: String, model: LLMModel, prompt: String, apiKey: String, thinkingEnabled: Bool = false) async -> CleanupResult {
        // Check if text is too long for AI cleanup
        if text.count > Self.maxCharacterCount {
            let warning = "Transcription too long for AI cleanup (\(text.count / 1000)K characters). Manual cleanup required."
            logger.warning("Skipping AI cleanup: text too long (\(text.count) characters)")
            return CleanupResult(text: text, warning: warning, usedOriginal: true, cost: nil, inputTokens: nil, outputTokens: nil)
        }

        do {
            let (cleanedText, inputTokens, outputTokens) = try await performCleanup(text: text, model: model, prompt: prompt, apiKey: apiKey, thinkingEnabled: thinkingEnabled)
            let cost = model.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens)
            logger.info("AI cleanup succeeded using \(model.rawValue)\(thinkingEnabled ? " (thinking)" : "") - \(inputTokens) in, \(outputTokens) out, $\(String(format: "%.6f", cost))")
            return CleanupResult(text: cleanedText, warning: nil, usedOriginal: false, cost: cost, inputTokens: inputTokens, outputTokens: outputTokens)
        } catch {
            let warning = warningMessage(for: error)
            logger.error("AI cleanup failed: \(error.localizedDescription, privacy: .public)")
            return CleanupResult(text: text, warning: warning, usedOriginal: true, cost: nil, inputTokens: nil, outputTokens: nil)
        }
    }

    private func performCleanup(text: String, model: LLMModel, prompt: String, apiKey: String, thinkingEnabled: Bool) async throws -> (text: String, inputTokens: Int, outputTokens: Int) {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let userMessage = buildPrompt(transcription: text, customInstructions: prompt, thinkingEnabled: thinkingEnabled)

        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": thinkingEnabled ? 16000 : 4096,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        if thinkingEnabled {
            body["thinking"] = [
                "type": "enabled",
                "budget_tokens": 10000
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMCleanupError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try parseResponse(data)
        case 401:
            logger.warning("API key invalid or expired")
            throw LLMCleanupError.invalidAPIKey
        case 429:
            logger.warning("Rate limited by Anthropic API")
            throw LLMCleanupError.rateLimited
        case 500...599:
            logger.warning("Anthropic API server error: \(httpResponse.statusCode)")
            throw LLMCleanupError.serverError(httpResponse.statusCode)
        default:
            logger.warning("Unexpected HTTP status: \(httpResponse.statusCode)")
            throw LLMCleanupError.serverError(httpResponse.statusCode)
        }
    }

    private func buildPrompt(transcription: String, customInstructions: String, thinkingEnabled: Bool = false) -> String {
        var prompt = """
        You are a text cleanup assistant. Your task is to transform raw speech-to-text transcription into clean, readable written text suitable for professional but informal communication (Slack messages, emails, notes, etc.).

        Here is the transcription to clean up:

        <transcription>
        \(transcription)
        </transcription>

        Your goal is to remove the artifacts of spoken language while preserving the speaker's authentic voice, tone, and meaning. This should be a light-to-moderate cleanup — fix clear issues without over-polishing.

        **Transformations to perform:**

        1. **Remove filler words entirely:** Delete um, uh, er, ah, like (when filler), you know, I mean, basically, actually, sort of, kind of, right?, literally (when filler), and so (when meaningless at sentence starts).

        2. **Fix false starts and self-corrections:** When the speaker restarts a thought, keep only the final intended version.
           - Example: "I want to— we should probably schedule" → "We should probably schedule"

        3. **Remove accidental repetition:** Delete words or phrases repeated due to speech disfluency.
           - Example: "I think we we should" → "I think we should"

        4. **Preserve intentional repetition:** Keep repetition that's clearly for emphasis.
           - Example: "This is really, really important" stays as-is

        5. **Fix grammar and punctuation:** Correct obvious errors and add appropriate punctuation. However, keep grammatically casual constructions that reflect natural speech patterns.

        6. **Add paragraph breaks:** Insert breaks only when there's a clear topic shift or when it genuinely aids readability. Don't over-segment.

        7. **Format lists:** When the speaker clearly enumerates items (using "first, second, third" or "one, two, three" or listing parallel items), format as a bulleted or numbered list.

        8. **Preserve tone:** Keep casual speech casual. Keep emphatic speech emphatic. The output should sound like the same person without verbal artifacts.

        **What NOT to do:**
        - Don't add information that wasn't present
        - Don't change the meaning or intent
        - Don't make casual language formal
        - Don't restructure clear sentences unnecessarily
        - Don't add hedging language or soften direct statements
        - Don't remove intentional emphasis or personality

        """

        if !customInstructions.isEmpty {
            prompt += """

            **Additional instructions from user:**
            \(customInstructions)

            """
        }

        if thinkingEnabled {
            prompt += """
            Think through any ambiguous cases where you need to decide whether something is intentional emphasis vs. disfluency, or whether language is casually grammatical vs. actually incorrect.

            Then provide your cleaned transcription inside <cleaned_text> tags. Output only the cleaned text itself — no explanations, metadata, or comments about changes made.
            """
        } else {
            prompt += """
            **Process:**

            First, use the scratchpad to identify any ambiguous cases where you need to decide whether something is intentional emphasis vs. disfluency, or whether language is casually grammatical vs. actually incorrect.

            <scratchpad>
            [Think through any ambiguous cases here]
            </scratchpad>

            Then provide your cleaned transcription inside <cleaned_text> tags. Output only the cleaned text itself — no explanations, metadata, or comments about changes made.
            """
        }

        return prompt
    }

    private func parseResponse(_ data: Data) throws -> (text: String, inputTokens: Int, outputTokens: Int) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            logger.error("Failed to parse API response JSON")
            throw LLMCleanupError.invalidResponse
        }

        // Extract token usage
        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        // Extract content from <cleaned_text> tags
        if let startRange = text.range(of: "<cleaned_text>"),
           let endRange = text.range(of: "</cleaned_text>") {
            let cleanedText = String(text[startRange.upperBound..<endRange.lowerBound])
            return (cleanedText.trimmingCharacters(in: .whitespacesAndNewlines), inputTokens, outputTokens)
        }

        // Fallback: return the whole response trimmed if tags not found
        logger.warning("Response missing <cleaned_text> tags, using raw response")
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), inputTokens, outputTokens)
    }

    private func warningMessage(for error: Error) -> String {
        if let llmError = error as? LLMCleanupError {
            switch llmError {
            case .invalidAPIKey:
                return "AI cleanup failed: Invalid API key. Check Settings."
            case .networkError:
                return "AI cleanup failed: Network error. Using original text."
            case .rateLimited:
                return "AI cleanup failed: Rate limited. Using original text."
            case .serverError:
                return "AI cleanup failed: Server error. Using original text."
            case .invalidResponse:
                return "AI cleanup failed: Invalid response. Using original text."
            case .timeout:
                return "AI cleanup failed: Request timed out. Using original text."
            case .textTooLong:
                return "AI cleanup failed: Text too long. Using original text."
            }
        } else if (error as NSError).code == NSURLErrorTimedOut {
            return "AI cleanup failed: Request timed out. Using original text."
        } else if (error as NSError).code == NSURLErrorNotConnectedToInternet {
            return "AI cleanup failed: No internet connection. Using original text."
        } else {
            return "AI cleanup failed: \(error.localizedDescription). Using original text."
        }
    }

    func validateAPIKey(_ apiKey: String) async -> Bool {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": LLMModel.haiku.rawValue,
            "max_tokens": 1,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            // 200 means valid, 401 means invalid key
            // Other errors (rate limit, etc.) mean the key format is valid
            return httpResponse.statusCode != 401
        } catch {
            // Network errors don't invalidate the key
            return true
        }
    }
}
