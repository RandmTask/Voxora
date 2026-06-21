import Foundation
import SwiftData

@Model
final class NoteTag {
  var id: UUID = UUID()
  var name: String = ""
  var createdAt: Date = Date()
  var updatedAt: Date = Date()

  init(id: UUID = UUID(), name: String) {
    self.id = id
    self.name = name
  }
}
