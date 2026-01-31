//
//  GlossaryManager.swift
//  RantToMe
//

import Foundation

@MainActor
@Observable
final class GlossaryManager {
    private(set) var entries: [GlossaryEntry] = []

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("glossary.json")
    }

    init() {
        loadEntries()
    }

    func applyReplacements(to text: String) -> String {
        var result = text
        for entry in entries where !entry.find.isEmpty {
            result = result.replacingOccurrences(of: entry.find, with: entry.replace)
        }
        return result
    }

    func hasKey(_ find: String, excludingID: UUID? = nil) -> Bool {
        entries.contains { entry in
            entry.find == find && entry.id != excludingID
        }
    }

    func addEntry(_ entry: GlossaryEntry) -> Bool {
        guard !hasKey(entry.find) else { return false }
        entries.append(entry)
        saveEntries()
        return true
    }

    func updateEntry(_ entry: GlossaryEntry) -> Bool {
        guard !hasKey(entry.find, excludingID: entry.id) else { return false }
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
            return true
        }
        return false
    }

    func deleteEntry(_ entry: GlossaryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([GlossaryEntry].self, from: data)
        } catch {
            // Start with empty entries if loading fails
        }
    }

    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL)
        } catch {
            // Silently fail - entries will be lost on restart
        }
    }
}
