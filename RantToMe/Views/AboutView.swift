//
//  AboutView.swift
//  RantToMe
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showingAttributions = false

    var body: some View {
        VStack(spacing: 20) {
            if appState.frogeModeEnabled {
                Image("BufoHappy")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }

            Text("RantToMe")
                .font(.title)
                .fontWeight(.bold)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Spacer()

            Button("Open Source Licenses") {
                showingAttributions = true
            }
            .buttonStyle(.link)

            Button("OK") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 350, height: 350)
        .sheet(isPresented: $showingAttributions) {
            OpenSourceAttributionsView()
        }
    }
}
