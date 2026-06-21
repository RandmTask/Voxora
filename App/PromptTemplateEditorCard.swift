import SwiftUI

struct PromptTemplateEditorCard: View {
  private static let symbolChoices = [
    "wand.and.stars",
    "checklist",
    "list.bullet.rectangle",
    "list.number",
    "text.badge.checkmark",
    "sparkles",
    "doc.text",
    "lightbulb",
    "calendar",
    "envelope"
  ]

  @Bindable var prompt: PromptTemplate
  var defaultProvider: AIProvider
  var onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Title", text: $prompt.title)
        .font(.headline)

      LabeledContent("Symbol") {
        Menu {
          ForEach(Self.symbolChoices, id: \.self) { symbolName in
            Button {
              prompt.iconName = symbolName
            } label: {
              Label(symbolName.replacingOccurrences(of: ".", with: " "), systemImage: symbolName)
            }
          }
        } label: {
          Image(systemName: prompt.iconName)
            .font(.title3)
            .frame(width: 32, height: 32)
        }
      }

      LabeledContent("Provider") {
        Menu {
          Button(defaultProvider.title) {
            prompt.providerOverride = nil
          }
          ForEach(AIProvider.allCases.filter { $0 != defaultProvider }) { provider in
            Button(provider.title) {
              prompt.providerOverride = provider
            }
          }
        } label: {
          Text(effectiveProvider.title)
            .foregroundStyle(effectiveProvider.tint)
        }
      }

      Toggle("Enabled", isOn: $prompt.isEnabled)

      TextEditor(text: $prompt.promptBody)
        .frame(minHeight: 120)
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

      Button("Delete Action", systemImage: "trash", role: .destructive) {
        onDelete()
      }
      .foregroundStyle(.red)
      .tint(.red)
    }
    .padding(18)
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
  }

  private var effectiveProvider: AIProvider {
    prompt.providerOverride ?? defaultProvider
  }
}
