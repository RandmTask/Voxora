import Foundation
import SwiftData

enum VoxoraSchema {
  static let schema = Schema([
    AudioNote.self,
    PromptTemplate.self,
    NoteTag.self,
    NoteTagAssignment.self,
    GeneratedOutput.self,
    AutomationProfile.self,
    DeletedAudioNote.self
  ])
}
