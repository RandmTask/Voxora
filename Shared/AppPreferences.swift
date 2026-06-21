import Foundation

enum AppPreferences {
  static let recordingStateKey = "recordingState"
  static let recordingStartDateKey = "recordingStartDate"
  static let recordingChunkCountKey = "recordingChunkCount"
  static let primaryButtonBehaviorKey = "primaryButtonBehavior"
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
