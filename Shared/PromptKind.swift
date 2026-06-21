import Foundation

enum PromptKind: String, Codable, CaseIterable, Identifiable {
  case todo
  case bullets
  case custom

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .todo:
      "To-Do"
    case .bullets:
      "Bullets"
    case .custom:
      "Custom"
    }
  }

  var defaultTitle: String {
    switch self {
    case .todo:
      "To-Do Transformer"
    case .bullets:
      "Numbered/Bulleted List"
    case .custom:
      "Custom Action"
    }
  }

  var defaultPrompt: String {
    switch self {
    case .todo:
      """
      Transform the transcript into an actionable checklist.
      Convert implied work into concrete tasks.
      Output markdown checkboxes only.
      """
    case .bullets:
      """
      Distill the transcript into a clean hierarchy of numbered or bulleted points.
      Preserve important names, commitments, and dates.
      """
    case .custom:
      """
      Summarize the transcript into key takeaways, then draft the most useful next artifact for the user.
      Keep the result concise and structured.
      """
    }
  }

  var defaultIcon: String {
    switch self {
    case .todo: "checklist"
    case .bullets: "list.bullet.rectangle"
    case .custom: "wand.and.stars"
    }
  }

  var starterID: UUID {
    switch self {
    case .todo: UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
    case .bullets: UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!
    case .custom: UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!
    }
  }
}
