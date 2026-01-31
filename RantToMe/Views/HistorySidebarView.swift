//
//  HistorySidebarView.swift
//  RantToMe
//

import SwiftUI

struct HistorySidebarView: View {
    let history: [TranscriptionEntry]
    @Binding var selection: Set<UUID>
    let onDelete: ([TranscriptionEntry]) -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(history) { entry in
                HistoryRowView(entry: entry)
                    .tag(entry.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            let entriesToDelete = history.filter { selection.contains($0.id) || $0.id == entry.id }
                            onDelete(entriesToDelete)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }
}

struct HistoryRowView: View {
    let entry: TranscriptionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.sourceType == .recording ? "mic.fill" : "doc.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text(entry.timestamp, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.text.prefix(100) + (entry.text.count > 100 ? "..." : ""))
                .font(.subheadline)
                .lineLimit(2)

            if let fileName = entry.sourceFileName {
                Text(fileName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
