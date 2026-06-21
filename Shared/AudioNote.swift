import Foundation
import SwiftData

@Model
final class AudioNote {
  var id: UUID = UUID()
  var timestamp: Date = Date()
  var title: String = ""
  var transcriptText: String = ""
  var transformedOutputText: String = ""
  var processingStatusRawValue: String = AudioNoteProcessingStatus.idle.rawValue
  var tag: String? = nil
  var sourceRawValue: String = RecordingSource.iPhone.rawValue
  var isFavorite: Bool = false
  var archivedAt: Date? = nil
  var audioFileName: String = ""
  var duration: Double = 0
  var updatedAt: Date = Date()

  init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    title: String = "",
    transcriptText: String = "",
    transformedOutputText: String = "",
    processingStatus: AudioNoteProcessingStatus = .idle,
    tag: String? = nil,
    source: RecordingSource = .iPhone,
    isFavorite: Bool = false,
    archivedAt: Date? = nil,
    audioFileName: String = "",
    duration: Double = 0
  ) {
    self.id = id
    self.timestamp = timestamp
    self.title = title
    self.transcriptText = transcriptText
    self.transformedOutputText = transformedOutputText
    self.processingStatusRawValue = processingStatus.rawValue
    self.tag = tag
    self.sourceRawValue = source.rawValue
    self.isFavorite = isFavorite
    self.archivedAt = archivedAt
    self.audioFileName = audioFileName
    self.duration = duration
  }

  var source: RecordingSource {
    get { RecordingSource(rawValue: sourceRawValue) ?? .iPhone }
    set { sourceRawValue = newValue.rawValue }
  }

  var displayTitle: String {
    let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty
      ? timestamp.formatted(date: .abbreviated, time: .shortened)
      : cleaned
  }

  var processingStatus: AudioNoteProcessingStatus {
    get {
      AudioNoteProcessingStatus(rawValue: processingStatusRawValue) ?? .idle
    }
    set {
      processingStatusRawValue = newValue.rawValue
    }
  }
}
