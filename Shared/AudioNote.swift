import Foundation
import SwiftData

@Model
final class AudioNote {
  @Attribute(.unique) var id: UUID
  var timestamp: Date
  var transcriptText: String
  var transformedOutputText: String
  var processingStatusRawValue: String
  var tag: String?
  var audioFileName: String
  var duration: Double

  init(
    id: UUID = UUID(),
    timestamp: Date = .now,
    transcriptText: String = "",
    transformedOutputText: String = "",
    processingStatus: AudioNoteProcessingStatus = .idle,
    tag: String? = nil,
    audioFileName: String = "",
    duration: Double = 0
  ) {
    self.id = id
    self.timestamp = timestamp
    self.transcriptText = transcriptText
    self.transformedOutputText = transformedOutputText
    self.processingStatusRawValue = processingStatus.rawValue
    self.tag = tag
    self.audioFileName = audioFileName
    self.duration = duration
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
