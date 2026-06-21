import Foundation
import SwiftData

@Model
final class DeletedAudioNote {
  var id: UUID = UUID()
  var noteID: UUID = UUID()
  var deletedAt: Date = Date()

  init(noteID: UUID) {
    self.noteID = noteID
  }
}
