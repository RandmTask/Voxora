import Foundation

enum TranscriptionEngine: String, CaseIterable, Identifiable {
  case appleSpeech
  case whisper
  case gemini
  case openAI

  var id: String { rawValue }

  var title: String {
    switch self {
    case .appleSpeech: "Apple Speech"
    case .whisper: "Whisper (on-device)"
    case .gemini: "Gemini"
    case .openAI: "OpenAI"
    }
  }

  /// Runs entirely on-device — no audio leaves the phone, no API key needed.
  var isOnDevice: Bool {
    self == .appleSpeech || self == .whisper
  }
}
