//
//  TranscriptionDetailView.swift
//  RantToMe
//

import SwiftUI

struct TranscriptionDetailView: View {
    let entry: TranscriptionEntry
    let onCopy: (String) -> Void

    @State private var showingOriginal: Bool = false

    private var displayedText: String {
        if showingOriginal, let original = entry.originalText {
            return original
        }
        return entry.text
    }

    private var hasOriginal: Bool {
        entry.originalText != nil && entry.llmCleanupApplied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.sourceType == .recording ? "mic.fill" : "doc.fill")
                        Text(entry.sourceType == .recording ? "Recording" : "File")

                        if entry.llmCleanupApplied {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("AI cleaned")
                                if let cost = entry.llmCleanupCost {
                                    Text("(\(formatCost(cost)))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    .font(.headline)

                    Text(entry.timestamp, format: .dateTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let fileName = entry.sourceFileName {
                        Text(fileName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Button {
                    onCopy(displayedText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            if hasOriginal {
                Picker("Version", selection: $showingOriginal) {
                    Text("Cleaned").tag(false)
                    Text("Original").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            ScrollView {
                Text(displayedText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }
}
