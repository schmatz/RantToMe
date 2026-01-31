//
//  TranscriptionDetailView.swift
//  RantToMe
//

import SwiftUI

struct TranscriptionDetailView: View {
    let entry: TranscriptionEntry
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: entry.sourceType == .recording ? "mic.fill" : "doc.fill")
                        Text(entry.sourceType == .recording ? "Recording" : "File")
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
                    onCopy(entry.text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            Divider()

            ScrollView {
                Text(entry.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}
