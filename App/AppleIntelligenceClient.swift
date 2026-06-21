import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceClient {
  func generate(prompt: String) async throws -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      let model = SystemLanguageModel.default
      guard case .available = model.availability else {
        throw VoxoraAPIError.unavailableProvider(.appleIntelligence)
      }
      let session = LanguageModelSession(
        model: model,
        instructions: "You transform transcripts into polished, concise outputs for Voxora."
      )
      let response = try await session.respond(to: prompt)
      return response.content
    } else {
      throw VoxoraAPIError.unavailableProvider(.appleIntelligence)
    }
    #else
    throw VoxoraAPIError.unavailableProvider(.appleIntelligence)
    #endif
  }
}
