import Foundation

enum RecordingSource: String, CaseIterable, Identifiable {
  case iPhone
  case watch
  case either

  var id: String { rawValue }

  var title: String {
    switch self {
    case .iPhone: "iPhone"
    case .watch: "Watch"
    case .either: "Either"
    }
  }

  func matches(_ source: RecordingSource) -> Bool {
    self == .either || self == source
  }

  var systemImage: String {
    switch self {
    case .iPhone: "iphone"
    case .watch: "applewatch"
    case .either: "iphone"
    }
  }
}
