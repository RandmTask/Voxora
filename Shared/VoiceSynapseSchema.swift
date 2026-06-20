import Foundation
import SwiftData

enum VoiceSynapseSchema {
  static let schema = Schema([
    AudioNote.self,
    PromptTemplate.self
  ])
}
