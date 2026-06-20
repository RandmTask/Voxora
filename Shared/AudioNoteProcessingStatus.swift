import Foundation

enum AudioNoteProcessingStatus: String, Codable, CaseIterable, Identifiable {
  case idle
  case uploading
  case transcribing
  case ready

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .idle:
      "Idle"
    case .uploading:
      "Uploading"
    case .transcribing:
      "Transcribing"
    case .ready:
      "Ready"
    }
  }
}
