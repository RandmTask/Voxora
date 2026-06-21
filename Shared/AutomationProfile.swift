import Foundation
import SwiftData

@Model
final class AutomationProfile {
  var id: UUID = UUID()
  var title: String = ""
  var isEnabled: Bool = false
  var sourceRawValue: String = RecordingSource.either.rawValue
  var actionID: UUID = UUID()
  var generateTitle: Bool = true
  var createdAt: Date = Date()
  var updatedAt: Date = Date()

  init(
    id: UUID = UUID(),
    title: String,
    source: RecordingSource = .either,
    actionID: UUID,
    generateTitle: Bool = true
  ) {
    self.id = id
    self.title = title
    self.sourceRawValue = source.rawValue
    self.actionID = actionID
    self.generateTitle = generateTitle
  }

  var source: RecordingSource {
    get { RecordingSource(rawValue: sourceRawValue) ?? .either }
    set { sourceRawValue = newValue.rawValue }
  }
}
