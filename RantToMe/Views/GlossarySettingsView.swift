//
//  GlossarySettingsView.swift
//  RantToMe
//

import SwiftUI

struct GlossarySettingsView: View {
    @Environment(GlossaryManager.self) private var glossaryManager
    @State private var newFind: String = ""
    @State private var newReplace: String = ""

    private var isDuplicateKey: Bool {
        !newFind.isEmpty && glossaryManager.hasKey(newFind)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Find and replace text in transcriptions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

            Divider()

            // Entries list
            List {
                ForEach(glossaryManager.entries) { entry in
                    GlossaryEntryRow(entry: entry, glossaryManager: glossaryManager)
                }
            }
            .listStyle(.plain)

            Divider()

            // Add new entry form
            VStack(spacing: 8) {
                Text("Add New Entry")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Find", text: $newFind)
                            .textFieldStyle(.roundedBorder)
                        if isDuplicateKey {
                            Text("Key already exists")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    TextField("Replace", text: $newReplace)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)

                    Button {
                        addEntry()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(newFind.isEmpty || isDuplicateKey)
                }
            }
            .padding()
        }
    }

    private func addEntry() {
        let entry = GlossaryEntry(find: newFind, replace: newReplace)
        if glossaryManager.addEntry(entry) {
            newFind = ""
            newReplace = ""
        }
    }
}

struct GlossaryEntryRow: View {
    let entry: GlossaryEntry
    let glossaryManager: GlossaryManager

    @State private var editFind: String
    @State private var editReplace: String
    @State private var showDuplicateError: Bool = false

    init(entry: GlossaryEntry, glossaryManager: GlossaryManager) {
        self.entry = entry
        self.glossaryManager = glossaryManager
        self._editFind = State(initialValue: entry.find)
        self._editReplace = State(initialValue: entry.replace)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Find", text: $editFind)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: editFind) { _, newValue in
                        var updated = entry
                        updated.find = newValue
                        if !glossaryManager.updateEntry(updated) {
                            showDuplicateError = true
                            // Revert to original value
                            editFind = entry.find
                        } else {
                            showDuplicateError = false
                        }
                    }
                if showDuplicateError {
                    Text("Key already exists")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            TextField("Replace", text: $editReplace)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .onChange(of: editReplace) { _, newValue in
                    var updated = entry
                    updated.replace = newValue
                    _ = glossaryManager.updateEntry(updated)
                }

            Button {
                glossaryManager.deleteEntry(entry)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}
