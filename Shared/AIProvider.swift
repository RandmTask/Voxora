import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
  case appleIntelligence
  case gemini
  case deepSeek
  case openAI
  case anthropic

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .appleIntelligence:
      "Apple Intelligence"
    case .gemini:
      "Gemini"
    case .deepSeek:
      "DeepSeek"
    case .openAI:
      "OpenAI"
    case .anthropic:
      "Claude"
    }
  }

  var keychainKey: String {
    "provider.\(rawValue).apiKey"
  }
}
