import Foundation

struct WatchRecordingSnapshot {
  var state: RecordingState
  var startedAt: Date?
  var chunkCount: Int

  static func current() -> WatchRecordingSnapshot {
    let defaults = UserDefaults(suiteName: AppGroup.id)
    let rawState = defaults?.string(forKey: AppPreferences.recordingStateKey) ?? RecordingState.idle.rawValue
    let state = RecordingState(rawValue: rawState) ?? .idle
    let startedAt = defaults?.object(forKey: AppPreferences.recordingStartDateKey) as? Date
    let chunkCount = defaults?.integer(forKey: AppPreferences.recordingChunkCountKey) ?? 0
    return WatchRecordingSnapshot(state: state, startedAt: startedAt, chunkCount: chunkCount)
  }
}
