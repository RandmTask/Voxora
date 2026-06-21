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
    promptBody: String,
    provider: AIProvider
  ) async throws -> String {
    let prompt = """
    \(promptBody)

    Transcript:
    \(text)
    """

    return try await generate(prompt: prompt, provider: provider)
  }

  func generateTitle(text: String, provider: AIProvider) async throws -> String {
    let result = try await generate(
      prompt: """
      Create a concise title for this voice memo.
      Use at most eight words.
      Preserve important names or topics.
      Return only the title with no quotation marks or punctuation at the end.

      Voice memo:
      \(text)
      """,
      provider: provider
    )
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func test(provider: AIProvider) async throws -> String {
    let output = try await generate(
      prompt: "Reply with exactly: Voxora connection successful",
      provider: provider
    )
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func polishEmail(body: String, instructions: String, provider: AIProvider) async throws -> String {
    let guidance = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
    let prompt = """
    Rewrite the following voice memo as a polished email body.
    Preserve names, dates, commitments, and factual details.
    Return only the email body, with no subject line or commentary.
    \(guidance.isEmpty ? "" : "Style instructions: \(guidance)")

    Voice memo:
    \(body)
    """
    return try await generate(prompt: prompt, provider: provider)
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
