import SwiftUI

struct AutomationProfileEditorCard: View {
  @Bindable var profile: AutomationProfile
  var actions: [PromptTemplate]
  var defaultProvider: AIProvider
  var onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Automation name", text: $profile.title)
        .font(.headline)

      Toggle("Enabled", isOn: $profile.isEnabled)

      Picker("Recording source", selection: Binding(
        get: { profile.source },
        set: { profile.source = $0 }
      )) {
        ForEach(RecordingSource.allCases) { source in
          Text(source.title).tag(source)
        }
      }
      .pickerStyle(.menu)

      Picker("Action", selection: $profile.actionID) {
        ForEach(actions) { action in
          Text(action.title).tag(action.id)
        }
      }
      .pickerStyle(.menu)

      Toggle("Generate title", isOn: $profile.generateTitle)

      if let action = actions.first(where: { $0.id == profile.actionID }),
         (action.providerOverride ?? defaultProvider).requiresAPIKey {
        Label(
          "Development only: this automation uses a raw device API key. A protected backend proxy is required before TestFlight.",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(.red)
      }

      Button("Delete Automation", systemImage: "trash", role: .destructive) {
        onDelete()
      }
    }
    .padding(.vertical, 6)
  }
}
