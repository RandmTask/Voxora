import Foundation

struct FinalizedRecording {
  var noteID: UUID
  var createdAt: Date
  var duration: TimeInterval
  var tag: String?
  var fileURL: URL
}
