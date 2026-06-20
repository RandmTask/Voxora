import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceClient {
  func generate(prompt: String) async throws -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      let session = LanguageModelSession(instructions: "You transform transcripts into polished outputs for VoiceSynapse.")
      let response = try await session.respond(to: prompt)
      return response.content
    } else {
      throw VoiceSynapseAPIError.unavailableProvider(.appleIntelligence)
    }
    #else
    throw VoiceSynapseAPIError.unavailableProvider(.appleIntelligence)
    #endif
  }
}
