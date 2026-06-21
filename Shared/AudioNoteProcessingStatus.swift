import Foundation

enum AudioNoteProcessingStatus: String, Codable, CaseIterable, Identifiable {
  case idle
  case uploading
  case transcribing
  case ready
  case tooShort
  case empty
  case failed

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
    case .tooShort:
      "Too short"
    case .empty:
      "Empty"
    case .failed:
      "Failed"
    }
  }
}
