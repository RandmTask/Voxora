import Foundation

enum TranscriptionEngine: String, CaseIterable, Identifiable {
  case appleSpeech
  case gemini
  case openAI

  var id: String { rawValue }

  var title: String {
    switch self {
    case .appleSpeech: "Apple Speech"
    case .gemini: "Gemini"
    case .openAI: "OpenAI"
    }
  }
}
