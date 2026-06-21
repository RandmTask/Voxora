import Foundation

enum PromptKind: String, Codable, CaseIterable, Identifiable {
  case todo
  case numbered
  case bullets
  case custom

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .todo:
      "To-Do"
    case .numbered:
      "Numbered"
    case .bullets:
      "Bullets"
    case .custom:
      "Custom"
    }
  }

  var defaultTitle: String {
    switch self {
    case .todo:
      "To Do"
    case .numbered:
      "Numbered List"
    case .bullets:
      "Bulleted List"
    case .custom:
      "Summarise"
    }
  }

  var defaultPrompt: String {
    switch self {
    case .todo:
      """
      Transform the transcript into an actionable checklist.
      Convert implied work into concrete tasks.
      Return markdown checkboxes only, with exactly one task per line.
      Begin every line with "- [ ] ". Do not add a heading or introductory prose.
      """
    case .numbered:
      """
      Distill the transcript into a concise numbered list.
      Preserve important names, commitments, dates, and sequence.
      Put exactly one item on each line using markdown numbering.
      Do not add a heading or introductory prose.
      """
    case .bullets:
      """
      Distill the transcript into a clean hierarchy of bulleted points.
      Preserve important names, commitments, and dates.
      Put exactly one item on each line using markdown bullets.
      Do not add a heading or introductory prose.
      """
    case .custom:
      """
      Summarise the transcript into concise key takeaways.
      Preserve important names, commitments, dates, and decisions.
      Use short paragraphs or markdown bullets where they improve clarity.
      """
    }
  }

  var defaultIcon: String {
    switch self {
    case .todo: "checklist"
    case .numbered: "list.number"
    case .bullets: "list.bullet.rectangle"
    case .custom: "wand.and.stars"
    }
  }

  var starterID: UUID {
    switch self {
    case .todo: UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
    case .numbered: UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!
    case .bullets: UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!
    case .custom: UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!
    }
  }
}
