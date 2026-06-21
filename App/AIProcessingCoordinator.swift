import Foundation

actor AIProcessingCoordinator {
  private let keychainStore: KeychainStore
  private let geminiClient = GeminiClient()
  private let deepSeekClient = DeepSeekClient()
  private let appleIntelligenceClient = AppleIntelligenceClient()
  private let openAIClient = OpenAIClient()
  private let anthropicClient = AnthropicClient()

  init(keychainStore: KeychainStore) {
    self.keychainStore = keychainStore
  }

  func transform(
    text: String,
    using template: PromptTemplate,
    provider: AIProvider? = nil
  ) async throws -> String {
    let prompt = """
    \(template.promptBody)

    Transcript:
    \(text)
    """

    return try await generate(prompt: prompt, provider: provider ?? template.preferredProvider)
  }

  func test(provider: AIProvider) async throws -> String {
    let output = try await generate(
      prompt: "Reply with exactly: Voxora connection successful",
      provider: provider
    )
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
    case .openAI:
      return try await openAIClient.generate(
        prompt: prompt,
        apiKey: keychainStore.value(for: provider.keychainKey)
      )
    case .anthropic:
      return try await anthropicClient.generate(
        prompt: prompt,
        apiKey: keychainStore.value(for: provider.keychainKey)
      )
    }
  }
}
