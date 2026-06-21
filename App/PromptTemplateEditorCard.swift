import SwiftUI

struct PromptTemplateEditorCard: View {
  @Bindable var prompt: PromptTemplate
  var defaultProvider: AIProvider
  var onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Title", text: $prompt.title)
        .font(.headline)

      TextField("SF Symbol", text: $prompt.iconName)

      Picker("Provider", selection: Binding(
        get: { prompt.providerOverride },
        set: { prompt.providerOverride = $0 }
      )) {
        Text("Default (\(defaultProvider.title))").tag(AIProvider?.none)
        ForEach(AIProvider.allCases) { provider in
          Text(provider.title).tag(Optional(provider))
        }
      }
      .pickerStyle(.menu)

      Toggle("Enabled", isOn: $prompt.isEnabled)

      TextEditor(text: $prompt.promptBody)
        .frame(minHeight: 120)
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

      Button("Delete Action", systemImage: "trash", role: .destructive) {
        onDelete()
      }
    }
    .padding(18)
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
  }
}
