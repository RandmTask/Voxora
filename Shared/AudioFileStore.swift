import Foundation

enum AudioFileStore {
  static let directoryName = "AudioNotes"

  static func directoryURL() throws -> URL {
    let baseURL: URL
    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) {
      baseURL = containerURL
    } else {
      baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }

    let directoryURL = baseURL.appending(path: directoryName, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
  }

  static func destinationURL(noteID: UUID, fileExtension: String = "m4a") throws -> URL {
    try directoryURL().appending(path: "\(noteID.uuidString).\(fileExtension)")
  }

  @discardableResult
  static func copyAudioFile(from sourceURL: URL, noteID: UUID, fileExtension: String = "m4a") throws -> URL {
    let destinationURL = try destinationURL(noteID: noteID, fileExtension: fileExtension)
    if FileManager.default.fileExists(atPath: destinationURL.path()) {
      try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
  }

  static func removeAudioFile(named fileName: String) throws {
    let fileURL = try directoryURL().appending(path: fileName)
    guard FileManager.default.fileExists(atPath: fileURL.path()) else {
      return
    }
    try FileManager.default.removeItem(at: fileURL)
  }
}
