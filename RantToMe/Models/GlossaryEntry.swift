//
//  GlossaryEntry.swift
//  RantToMe
//

import Foundation

struct GlossaryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var find: String
    var replace: String

    init(id: UUID = UUID(), find: String, replace: String) {
        self.id = id
        self.find = find
        self.replace = replace
    }
}
