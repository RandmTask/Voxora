import Foundation
import SwiftData

@Model
final class PromptTemplate {
  var kindRawValue: String = PromptKind.custom.rawValue
  var title: String = ""
  var promptBody: String = ""
  var preferredProviderRawValue: String = AIProvider.appleIntelligence.rawValue

  init(
    kind: PromptKind,
    title: String? = nil,
    promptBody: String? = nil,
    preferredProvider: AIProvider = .appleIntelligence
  ) {
    self.kindRawValue = kind.rawValue
    self.title = title ?? kind.defaultTitle
    self.promptBody = promptBody ?? kind.defaultPrompt
    self.preferredProviderRawValue = preferredProvider.rawValue
  }

  var kind: PromptKind {
    PromptKind(rawValue: kindRawValue) ?? .custom
  }

  var preferredProvider: AIProvider {
    get {
      AIProvider(rawValue: preferredProviderRawValue) ?? .appleIntelligence
    }
    set {
      preferredProviderRawValue = newValue.rawValue
    }
  }
}
