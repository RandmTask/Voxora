import Foundation

enum AppPreferences {
  static let appearanceKey = "settings.appearance"
  static let recordingStateKey = "recordingState"
  static let recordingStartDateKey = "recordingStartDate"
  static let recordingChunkCountKey = "recordingChunkCount"
  static let recordingNoteIDKey = "recordingNoteID"
  static let phonePrimaryButtonBehaviorKey = "phonePrimaryButtonBehavior"
  static let watchPrimaryButtonBehaviorKey = "watchPrimaryButtonBehavior"
  static let defaultAIProviderKey = "defaultAIProvider"
  static let defaultEmailRecipientKey = "defaultEmailRecipient"
  static let emailSubjectPrefixKey = "emailSubjectPrefix"
  static let includeTimestampInExportsKey = "includeTimestampInExports"
  static let hideUnusableNotesKey = "hideUnusableNotes"
  static let hideFailedNotesKey = "hideFailedNotes"
  static let showArchivedNotesKey = "showArchivedNotes"
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
