import Foundation
import SwiftData

@Model
final class NoteTag {
  var id: UUID = UUID()
  var name: String = ""
  /// Hex colour for the tag pill background. Defaults to violet.
  var colorHex: String = "#7C5CFC"
  /// Pinned tags sort to the front of the filter strip and manage list.
  var isPinned: Bool = false
  var createdAt: Date = Date()
  var updatedAt: Date = Date()

  init(id: UUID = UUID(), name: String, colorHex: String = "#7C5CFC", isPinned: Bool = false) {
    self.id = id
    self.name = name
    self.colorHex = colorHex
    self.isPinned = isPinned
  }
}
