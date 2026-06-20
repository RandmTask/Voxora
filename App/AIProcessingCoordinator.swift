import Foundation

actor AIProcessingCoordinator {
  private let keychainStore: KeychainStore
  private let geminiClient = GeminiClient()
  private let deepSeekClient = DeepSeekClient()
  private let appleIntelligenceClient = AppleIntelligenceClient()

  init(keychainStore: KeychainStore) {
    self.keychainStore = keychainStore
  }

  func transform(text: String, using template: PromptTemplate) async throws -> String {
    let prompt = """
    \(template.promptBody)

    Transcript:
    \(text)
    """

    for provider in providerOrder(preferred: template.preferredProvider) {
      do {
        return try await generate(prompt: prompt, provider: provider)
      } catch VoiceSynapseAPIError.missingAPIKey {
        continue
      } catch VoiceSynapseAPIError.unavailableProvider {
        continue
      } catch {
        continue
      }
    }

    throw VoiceSynapseAPIError.unavailableProvider(template.preferredProvider)
  }

  private func providerOrder(preferred: AIProvider) -> [AIProvider] {
    let baseOrder: [AIProvider] = [
      preferred,
      .gemini,
      .deepSeek,
      .appleIntelligence,
      .openAI,
      .anthropic
    ]

    var seen: Set<AIProvider> = []
    return baseOrder.filter { seen.insert($0).inserted }
  }

  private func generate(prompt: String, provider: AIProvider) async throws -> String {
    switch provider {
    case .appleIntelligence:
      return try await appleIntelligenceClient.generate(prompt: prompt)
    case .gemini:
      return try await geminiClient.generate(
        prompt: prompt,
        apiKey: keychainStore.value(for: provider.keychainKey)
      )
    case .deepSeek:
      return try await deepSeekClient.generate(
        prompt: prompt,
        apiKey: keychainStore.value(for: provider.keychainKey)
      )
    case .openAI, .anthropic:
      throw VoiceSynapseAPIError.unavailableProvider(provider)
    }
  }
}
