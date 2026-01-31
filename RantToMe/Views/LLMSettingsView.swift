//
//  LLMSettingsView.swift
//  RantToMe
//

import SwiftUI

struct LLMSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String?
    @State private var showAPIKeyField: Bool = false
    @State private var hasStoredKey: Bool = KeychainService.hasAnthropicAPIKey

    private let llmService = LLMCleanupService()

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section {
                Toggle("Enable AI cleanup", isOn: enabledBinding)
                    .disabled(!hasStoredKey)
            } header: {
                Text("AI Text Cleanup")
            } footer: {
                Text("Uses Claude to improve grammar, punctuation, and formatting after transcription. Requires an Anthropic API key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if hasStoredKey && !showAPIKeyField {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text("Configured")
                            .foregroundStyle(.secondary)
                        Button("Change") {
                            showAPIKeyField = true
                            apiKeyInput = ""
                        }
                        .buttonStyle(.link)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Enter Anthropic API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)

                        if let error = validationError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        HStack {
                            Button("Save Key") {
                                Task { await saveAPIKey() }
                            }
                            .disabled(apiKeyInput.isEmpty || isValidating)

                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }

                            Spacer()

                            if hasStoredKey {
                                Button("Cancel") {
                                    showAPIKeyField = false
                                    apiKeyInput = ""
                                    validationError = nil
                                }
                            }
                        }
                    }
                }

                if hasStoredKey {
                    Button("Remove API Key", role: .destructive) {
                        removeAPIKey()
                    }
                }

                Link("Get API Key", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                    .font(.caption)
            } header: {
                Text("API Key")
            }

            Section {
                Picker("Model", selection: $appState.llmCleanupModel) {
                    ForEach(LLMModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                Toggle("Enable extended thinking", isOn: $appState.llmCleanupThinkingEnabled)
            } header: {
                Text("Model Selection")
            } footer: {
                Text("Extended thinking improves quality for complex text but increases latency and cost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!appState.llmCleanupEnabled)
            .opacity(appState.llmCleanupEnabled ? 1 : 0.5)

            Section {
                TextEditor(text: $appState.llmCleanupPrompt)
                    .font(.body)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)

                if !appState.llmCleanupPrompt.isEmpty {
                    Button("Clear") {
                        appState.llmCleanupPrompt = ""
                    }
                    .font(.caption)
                }
            } header: {
                Text("Additional Instructions (Optional)")
            } footer: {
                Text("Add custom instructions to supplement the built-in cleanup rules. Leave empty to use defaults only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!appState.llmCleanupEnabled)
            .opacity(appState.llmCleanupEnabled ? 1 : 0.5)

            if appState.totalLLMCleanupCost > 0 {
                Section {
                    HStack {
                        Text("Total AI Cleanup Spend")
                        Spacer()
                        Text(formatCost(appState.totalLLMCleanupCost))
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                } footer: {
                    Text("Total cost across all transcriptions in history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { appState.llmCleanupEnabled },
            set: { newValue in
                if newValue && !hasStoredKey {
                    // Don't enable without API key
                    return
                }
                appState.llmCleanupEnabled = newValue
            }
        )
    }

    private func saveAPIKey() async {
        isValidating = true
        validationError = nil

        let isValid = await llmService.validateAPIKey(apiKeyInput)

        await MainActor.run {
            isValidating = false

            if isValid {
                do {
                    try KeychainService.saveAnthropicAPIKey(apiKeyInput)
                    hasStoredKey = true
                    showAPIKeyField = false
                    apiKeyInput = ""
                } catch {
                    validationError = "Failed to save key: \(error.localizedDescription)"
                }
            } else {
                validationError = "Invalid API key. Please check and try again."
            }
        }
    }

    private func removeAPIKey() {
        try? KeychainService.deleteAnthropicAPIKey()
        hasStoredKey = false
        appState.llmCleanupEnabled = false
        showAPIKeyField = false
        apiKeyInput = ""
    }
}
