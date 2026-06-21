import Foundation
import SwiftUI

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

  var requiresAPIKey: Bool {
    self != .appleIntelligence
  }

  var tint: Color {
    switch self {
    case .appleIntelligence: .blue
    case .gemini: .cyan
    case .deepSeek: .indigo
    case .openAI: .green
    case .anthropic: .orange
    }
  }
}
