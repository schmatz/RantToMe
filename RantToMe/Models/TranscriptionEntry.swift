//
//  TranscriptionEntry.swift
//  RantToMe
//

import Foundation

enum SourceType: String, Codable {
    case recording
    case file
}

struct TranscriptionEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let text: String
    let sourceType: SourceType
    let sourceFileName: String?
    let originalText: String?
    let llmCleanupApplied: Bool
    let llmCleanupCost: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        sourceType: SourceType,
        sourceFileName: String? = nil,
        originalText: String? = nil,
        llmCleanupApplied: Bool = false,
        llmCleanupCost: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.sourceType = sourceType
        self.sourceFileName = sourceFileName
        self.originalText = originalText
        self.llmCleanupApplied = llmCleanupApplied
        self.llmCleanupCost = llmCleanupCost
    }

    // Custom decoding to handle backward compatibility with existing history
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        text = try container.decode(String.self, forKey: .text)
        sourceType = try container.decode(SourceType.self, forKey: .sourceType)
        sourceFileName = try container.decodeIfPresent(String.self, forKey: .sourceFileName)
        originalText = try container.decodeIfPresent(String.self, forKey: .originalText)
        llmCleanupApplied = try container.decodeIfPresent(Bool.self, forKey: .llmCleanupApplied) ?? false
        llmCleanupCost = try container.decodeIfPresent(Double.self, forKey: .llmCleanupCost)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, text, sourceType, sourceFileName, originalText, llmCleanupApplied, llmCleanupCost
    }
}
