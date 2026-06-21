import SwiftUI

struct SettingsView: View {
  @Bindable var store: VoxoraStore
  @Environment(\.dismiss) private var dismiss
  @State private var providerDrafts: [AIProvider: String] = [:]

  var body: some View {
    NavigationStack {
      Form {
        Section("Recording") {
          Picker("Big button while recording", selection: Binding(
            get: { store.primaryButtonBehavior },
            set: { store.primaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
        }

        Section("Apple Intelligence") {
          Label("Runs privately on-device—no API key required.", systemImage: "apple.intelligence")
          Button("Test Apple Intelligence") {
            Task { await store.testProvider(.appleIntelligence) }
          }
          if let result = store.providerTestResults[.appleIntelligence] {
            Text(result).font(.caption).foregroundStyle(.secondary)
          }
        }

        Section("Cloud AI providers") {
          ForEach(AIProvider.allCases.filter { $0.requiresAPIKey }) { provider in
            VStack(alignment: .leading, spacing: 10) {
              Text(provider.title).font(.headline)
              SecureField("API key", text: Binding(
                get: { providerDrafts[provider] ?? "" },
                set: { providerDrafts[provider] = $0 }
              ))
              .textContentType(.password)

              HStack {
                Button("Save") {
                  store.saveAPIKey(providerDrafts[provider] ?? "", for: provider)
                }
                Button("Test") {
                  store.saveAPIKey(providerDrafts[provider] ?? "", for: provider)
                  Task { await store.testProvider(provider) }
                }
              }
              if let result = store.providerTestResults[provider] {
                Text(result).font(.caption).foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 6)
          }
        }

        Section("Prompt templates") {
          ForEach(store.prompts) { prompt in
            PromptTemplateEditorCard(prompt: prompt)
          }
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            store.persistChanges()
            dismiss()
          }
        }
      }
      .task {
        for provider in AIProvider.allCases where provider.requiresAPIKey {
          providerDrafts[provider] = store.apiKey(for: provider)
        }
      }
    }
  }
}
