import Foundation

enum AppPreferences {
  static let recordingStateKey = "recordingState"
  static let recordingStartDateKey = "recordingStartDate"
  static let recordingChunkCountKey = "recordingChunkCount"
  static let recordingNoteIDKey = "recordingNoteID"
  static let phonePrimaryButtonBehaviorKey = "phonePrimaryButtonBehavior"
  static let watchPrimaryButtonBehaviorKey = "watchPrimaryButtonBehavior"
  static let defaultAIProviderKey = "defaultAIProvider"
  static let defaultEmailRecipientKey = "defaultEmailRecipient"
}

enum PrimaryButtonBehavior: String, CaseIterable, Identifiable {
  case pause
  case finish

  var id: String { rawValue }

  var title: String {
    switch self {
    case .pause: "Pause recording"
    case .finish: "Finish recording"
    }
  }
}
