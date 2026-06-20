import Foundation

enum DeepLinkRoute: Equatable {
  case record
  case note(UUID)

  init?(url: URL) {
    guard url.scheme == "voicesynapse" else {
      return nil
    }

    if url.host == "record" {
      self = .record
      return
    }

    if url.host == "note",
       let idString = url.pathComponents.dropFirst().first,
       let id = UUID(uuidString: idString) {
      self = .note(id)
      return
    }

    return nil
  }
}
