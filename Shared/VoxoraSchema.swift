import Foundation
import SwiftData

enum VoxoraSchema {
  static let schema = Schema([
    AudioNote.self,
    PromptTemplate.self
  ])
}
