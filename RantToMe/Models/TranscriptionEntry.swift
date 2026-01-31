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

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, sourceType: SourceType, sourceFileName: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.sourceType = sourceType
        self.sourceFileName = sourceFileName
    }
}
