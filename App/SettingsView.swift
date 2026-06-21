import SwiftUI

struct SettingsView: View {
  @Bindable var store: VoxoraStore
  @Environment(\.dismiss) private var dismiss
  @State private var providerDrafts: [AIProvider: String] = [:]
  @State private var editingAction: PromptTemplate?
  @State private var editingAutomation: AutomationProfile?
  @State private var pendingActionDelete: PromptTemplate?
  @State private var pendingAutomationDelete: AutomationProfile?
  @State private var pendingTagDelete: NoteTag?

  var body: some View {
    NavigationStack {
      Form {
        Section("Recording controls") {
          Picker("iPhone tap action", selection: Binding(
            get: { store.phonePrimaryButtonBehavior },
            set: { store.phonePrimaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
          .pickerStyle(.menu)

          Picker("Apple Watch tap action", selection: Binding(
            get: { store.watchPrimaryButtonBehavior },
            set: { store.watchPrimaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
          .pickerStyle(.menu)
        }

        Section("Preferences") {
          NavigationLink {
            emailSettings
          } label: {
            settingsRow("Email", systemImage: "envelope", detail: emailSettingsDetail)
          }

          NavigationLink {
            aiModelSettings
          } label: {
            settingsRow(
              "AI Model",
              systemImage: "apple.intelligence",
              detail: store.defaultAIProvider.title,
              tint: store.defaultAIProvider.tint
            )
          }
        }

        Section("Organize and automate") {
          NavigationLink {
            aiActionsSettings
          } label: {
            settingsRow("AI Actions", systemImage: "sparkles", detail: "\(store.prompts.count)")
          }

          NavigationLink {
            automationsSettings
          } label: {
            settingsRow(
              "Automations",
              systemImage: "bolt.badge.clock",
              detail: "\(store.automationProfiles.count)"
            )
          }

          NavigationLink {
            tagsSettings
          } label: {
            settingsRow("Tags", systemImage: "tag", detail: "\(store.tags.count)")
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
      .sheet(item: $editingAction) { prompt in
        NavigationStack {
          ScrollView {
            PromptTemplateEditorCard(
              prompt: prompt,
              defaultProvider: store.defaultAIProvider,
              onDelete: {
                editingAction = nil
                pendingActionDelete = prompt
              }
            )
            .padding(20)
          }
          .navigationTitle(prompt.title.isEmpty ? "AI Action" : prompt.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") {
                store.persistChanges()
                editingAction = nil
              }
            }
          }
        }
      }
      .sheet(item: $editingAutomation) { profile in
        NavigationStack {
          Form {
            AutomationProfileEditorCard(
              profile: profile,
              actions: store.prompts,
              defaultProvider: store.defaultAIProvider,
              onDelete: {
                editingAutomation = nil
                pendingAutomationDelete = profile
              }
            )
          }
          .navigationTitle(profile.title.isEmpty ? "Automation" : profile.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") {
                store.persistChanges()
                editingAutomation = nil
              }
            }
          }
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

  private var emailSettings: some View {
    Form {
      Section("Email settings") {
        TextField("Default recipient", text: Binding(
          get: { store.defaultEmailRecipient },
          set: { store.defaultEmailRecipient = $0 }
        ))
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .keyboardType(.emailAddress)

        TextField("Subject prefix", text: Binding(
          get: { store.emailSubjectPrefix },
          set: { store.emailSubjectPrefix = $0 }
        ))
      }
    }
    .navigationTitle("Email")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var aiModelSettings: some View {
    Form {
      Section("Provider") {
        Picker("Provider", selection: Binding(
          get: { store.defaultAIProvider },
          set: { store.defaultAIProvider = $0 }
        )) {
          ForEach(AIProvider.allCases) { provider in
            Text(provider.title).tag(provider)
          }
        }
        .pickerStyle(.menu)
        .tint(store.defaultAIProvider.tint)

        if store.defaultAIProvider.requiresAPIKey {
          Label(
            "Development only: raw API keys require a protected backend before TestFlight.",
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
          .foregroundStyle(.blue)
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
    }
    .navigationTitle("AI Model")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var aiActionsSettings: some View {
    List {
      ForEach(store.prompts) { prompt in
        Button {
          editingAction = prompt
        } label: {
          HStack(spacing: 14) {
            Image(systemName: prompt.iconName)
              .font(.title3)
              .foregroundStyle((prompt.providerOverride ?? store.defaultAIProvider).tint)
              .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
              Text(prompt.title)
                .foregroundStyle(.primary)
              Text("Provider: \((prompt.providerOverride ?? store.defaultAIProvider).title)")
                .font(.caption)
                .foregroundStyle(
                  (prompt.providerOverride ?? store.defaultAIProvider).tint
                )
            }

            Spacer()

            if !prompt.isEnabled {
              Text("Off")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .navigationTitle("AI Actions")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add Action", systemImage: "plus") {
          editingAction = store.addAction()
        }
      }
    }
  }

  private var automationsSettings: some View {
    List {
      ForEach(store.automationProfiles) { profile in
        Button {
          editingAutomation = profile
        } label: {
          HStack(spacing: 14) {
            Image(systemName: "bolt.badge.clock")
              .foregroundStyle(profile.isEnabled ? .blue : .secondary)
              .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
              Text(profile.title)
                .foregroundStyle(.primary)
              Text(profile.isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .navigationTitle("Automations")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add Automation", systemImage: "plus") {
          store.addAutomationProfile()
          editingAutomation = store.automationProfiles.last
        }
      }
    }
  }

  private var tagsSettings: some View {
    List {
      ForEach(store.tags) { tag in
        HStack {
          Label(tag.name, systemImage: "tag")
          Spacer()
          Button("Delete", systemImage: "trash", role: .destructive) {
            pendingTagDelete = tag
          }
          .labelStyle(.iconOnly)
          .foregroundStyle(.red)
          .tint(.red)
        }
      }
    }
    .navigationTitle("Tags")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var emailSettingsDetail: String {
    let recipient = store.defaultEmailRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
    return recipient.isEmpty ? "Not configured" : recipient
  }

  private func settingsRow(
    _ title: String,
    systemImage: String,
    detail: String,
    tint: Color = .blue
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .foregroundStyle(tint)
        .frame(width: 24)
      Text(title)
      Spacer()
      Text(detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private func saveSelectedAPIKey() {
    let provider = store.defaultAIProvider
    guard provider.requiresAPIKey else { return }
    store.saveAPIKey(providerDrafts[provider] ?? "", for: provider)
  }
}
