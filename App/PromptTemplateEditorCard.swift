import SwiftUI

struct PromptTemplateEditorCard: View {
  @Bindable var prompt: PromptTemplate

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Title", text: $prompt.title)
        .font(.headline)

      Picker("Provider", selection: $prompt.preferredProviderRawValue) {
        ForEach(AIProvider.allCases) { provider in
          Text(provider.title).tag(provider.rawValue)
        }
      }
      .pickerStyle(.menu)
      .buttonStyle(.glass)

      TextEditor(text: $prompt.promptBody)
        .frame(minHeight: 120)
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .padding(18)
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
  }
}
