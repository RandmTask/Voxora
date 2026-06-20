import SwiftUI

struct SettingsView: View {
  @Bindable var store: VoiceSynapseStore
  @Environment(\.dismiss) private var dismiss

  @State private var providerDrafts: [AIProvider: String] = [:]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          promptSection
          credentialsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
      }
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.1, green: 0.12, blue: 0.17),
            Color(red: 0.16, green: 0.19, blue: 0.28),
            Color(red: 0.34, green: 0.46, blue: 0.68)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
      )
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
        for provider in AIProvider.allCases {
          providerDrafts[provider] = store.apiKey(for: provider)
        }
      }
    }
  }

  private var promptSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Prompt Templates")
        .font(.headline)

      ForEach(store.prompts) { prompt in
        PromptTemplateEditorCard(prompt: prompt)
      }
    }
  }

  private var credentialsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Provider Keys")
        .font(.headline)

      ForEach(AIProvider.allCases) { provider in
        VStack(alignment: .leading, spacing: 10) {
          Text(provider.title)
            .font(.subheadline.weight(.semibold))

          SecureField("API Key", text: Binding(
            get: { providerDrafts[provider] ?? "" },
            set: { providerDrafts[provider] = $0 }
          ))
          .textContentType(.password)
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

          Button("Save", systemImage: "key.horizontal") {
            store.saveAPIKey(providerDrafts[provider] ?? "", for: provider)
          }
          .buttonStyle(.glass)
        }
        .padding(18)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
      }
    }
  }
}
