import Foundation
import SwiftData

@Model
final class GeneratedOutput {
  var id: UUID = UUID()
  var noteID: UUID = UUID()
  var actionID: UUID = UUID()
  var actionTitle: String = ""
  var content: String = ""
  var createdAt: Date = Date()

  init(
    id: UUID = UUID(),
    noteID: UUID,
    actionID: UUID,
    actionTitle: String,
    content: String
  ) {
    self.id = id
    self.noteID = noteID
    self.actionID = actionID
    self.actionTitle = actionTitle
    self.content = content
  }
}
