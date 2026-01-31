//
//  ModelDownloadView.swift
//  RantToMe
//

import SwiftUI

struct ModelDownloadView: View {
    let onDownload: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Download Speech Model")
                .font(.title2)
                .fontWeight(.semibold)

            Text("RantToMe needs to download a speech recognition model to transcribe audio. The download will start automatically.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Download Model") {
                onDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}
