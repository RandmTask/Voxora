import Foundation

enum RecordingSource: String, CaseIterable, Identifiable {
  case iPhone
  case watch
  case imported
  case either

  var id: String { rawValue }

  var title: String {
    switch self {
    case .iPhone: "iPhone"
    case .watch: "Watch"
    case .imported: "Imported"
    case .either: "Any source"
    }
  }

  func matches(_ source: RecordingSource) -> Bool {
    self == .either || self == source
  }

  var systemImage: String {
    switch self {
    case .iPhone: "iphone"
    case .watch: "applewatch"
    case .imported: "square.and.arrow.down"
    case .either: "iphone"
    }
  }
}
