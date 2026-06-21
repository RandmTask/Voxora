import SwiftUI

struct SettingsView: View {
  @Bindable var store: VoxoraStore
  @Environment(\.dismiss) private var dismiss
  @State private var providerDrafts: [AIProvider: String] = [:]
  @State private var pendingActionDelete: PromptTemplate?
  @State private var pendingAutomationDelete: AutomationProfile?
  @State private var pendingTagDelete: NoteTag?

  var body: some View {
    NavigationStack {
      Form {
        Section("iPhone app") {
          Picker("Tap recording control", selection: Binding(
            get: { store.phonePrimaryButtonBehavior },
            set: { store.phonePrimaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
          .pickerStyle(.menu)

          TextField("Default email recipient", text: Binding(
            get: { store.defaultEmailRecipient },
            set: { store.defaultEmailRecipient = $0 }
          ))
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .keyboardType(.emailAddress)
        }

        Section("Apple Watch app") {
          Picker("Tap recording control", selection: Binding(
            get: { store.watchPrimaryButtonBehavior },
            set: { store.watchPrimaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
          .pickerStyle(.menu)
        }

        Section("AI model") {
          Picker("Model", selection: Binding(
            get: { store.defaultAIProvider },
            set: { store.defaultAIProvider = $0 }
          )) {
            ForEach(AIProvider.allCases) { provider in
              Text(provider.title).tag(provider)
            }
          }
          .pickerStyle(.menu)

          if store.defaultAIProvider.requiresAPIKey {
            Label(
              "Development only: raw API keys must be replaced with an authenticated, rate-limited backend proxy before TestFlight.",
              systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.red)

            SecureField("API key", text: Binding(
              get: { providerDrafts[store.defaultAIProvider] ?? "" },
              set: { providerDrafts[store.defaultAIProvider] = $0 }
            ))
            .textContentType(.password)

            Button("Save API Key") {
              saveSelectedAPIKey()
            }
          } else {
            Label(
              "Runs privately on-device—no API key required.",
              systemImage: "apple.intelligence"
            )
          }

          Button("Test \(store.defaultAIProvider.title)") {
            saveSelectedAPIKey()
            Task { await store.testProvider(store.defaultAIProvider) }
          }

          if let result = store.providerTestResults[store.defaultAIProvider] {
            Text(result)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section("AI actions") {
          ForEach(store.prompts) { prompt in
            PromptTemplateEditorCard(
              prompt: prompt,
              defaultProvider: store.defaultAIProvider,
              onDelete: { pendingActionDelete = prompt }
            )
          }

          Button("Add Action", systemImage: "plus") {
            _ = store.addAction()
          }
        }

        Section {
          ForEach(store.automationProfiles) { profile in
            AutomationProfileEditorCard(
              profile: profile,
              actions: store.prompts,
              defaultProvider: store.defaultAIProvider,
              onDelete: { pendingAutomationDelete = profile }
            )
          }

          Button("Add Automation", systemImage: "plus") {
            store.addAutomationProfile()
          }
        } header: {
          Text("Automations")
        } footer: {
          Text("Automations are opt-in and run one AI action after transcription.")
        }

        Section("Tags") {
          ForEach(store.tags) { tag in
            HStack {
              Text(tag.name)
              Spacer()
              Button("Delete", systemImage: "trash", role: .destructive) {
                pendingTagDelete = tag
              }
              .labelStyle(.iconOnly)
            }
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
      .confirmationDialog(
        "Delete this AI action?",
        isPresented: Binding(
          get: { pendingActionDelete != nil },
          set: { if !$0 { pendingActionDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Action", role: .destructive) {
          if let action = pendingActionDelete {
            store.deleteAction(action)
          }
          pendingActionDelete = nil
        }
        Button("Cancel", role: .cancel) {}
      }
      .confirmationDialog(
        "Delete this automation?",
        isPresented: Binding(
          get: { pendingAutomationDelete != nil },
          set: { if !$0 { pendingAutomationDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Automation", role: .destructive) {
          if let profile = pendingAutomationDelete {
            store.deleteAutomationProfile(profile)
          }
          pendingAutomationDelete = nil
        }
        Button("Cancel", role: .cancel) {}
      }
      .confirmationDialog(
        "Delete this tag?",
        isPresented: Binding(
          get: { pendingTagDelete != nil },
          set: { if !$0 { pendingTagDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Tag", role: .destructive) {
          if let tag = pendingTagDelete {
            store.deleteTag(tag)
          }
          pendingTagDelete = nil
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("The tag will be removed from notes, but no notes will be deleted.")
      }
    }
  }

  private func saveSelectedAPIKey() {
    let provider = store.defaultAIProvider
    guard provider.requiresAPIKey else { return }
    store.saveAPIKey(providerDrafts[provider] ?? "", for: provider)
  }
}
