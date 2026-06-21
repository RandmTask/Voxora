import Foundation
import SwiftData

@Model
final class PromptTemplate {
  var id: UUID = UUID()
  var kindRawValue: String = PromptKind.custom.rawValue
  var title: String = ""
  var promptBody: String = ""
  var iconName: String = "wand.and.stars"
  var providerOverrideRawValue: String = ""
  var sortOrder: Int = 0
  var isEnabled: Bool = true
  var createdAt: Date = Date()
  var updatedAt: Date = Date()

  init(
    id: UUID = UUID(),
    kind: PromptKind,
    title: String? = nil,
    promptBody: String? = nil,
    iconName: String? = nil,
    providerOverride: AIProvider? = nil,
    sortOrder: Int = 0
  ) {
    self.id = id
    self.kindRawValue = kind.rawValue
    self.title = title ?? kind.defaultTitle
    self.promptBody = promptBody ?? kind.defaultPrompt
    self.iconName = iconName ?? kind.defaultIcon
    self.providerOverrideRawValue = providerOverride?.rawValue ?? ""
    self.sortOrder = sortOrder
  }

  var kind: PromptKind {
    PromptKind(rawValue: kindRawValue) ?? .custom
  }

  var providerOverride: AIProvider? {
    get {
      AIProvider(rawValue: providerOverrideRawValue)
    }
    set {
      providerOverrideRawValue = newValue?.rawValue ?? ""
    }
  }
}
