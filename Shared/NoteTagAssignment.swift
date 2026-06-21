import Foundation
import SwiftData

@Model
final class NoteTagAssignment {
  var id: UUID = UUID()
  var noteID: UUID = UUID()
  var tagID: UUID = UUID()
  var createdAt: Date = Date()

  init(id: UUID = UUID(), noteID: UUID, tagID: UUID) {
    self.id = id
    self.noteID = noteID
    self.tagID = tagID
  }
}
