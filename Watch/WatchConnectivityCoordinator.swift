import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchConnectivityCoordinator: NSObject {
  var lastTransferDescription = "No transfer yet"
  private var pendingCleanupURLs: [URL] = []

  func activate() {
    guard WCSession.isSupported() else {
      return
    }

    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func transfer(recording: FinalizedRecording) {
    let metadata: [String: Any] = [
      TransferMetadata.noteID: recording.noteID.uuidString,
      TransferMetadata.createdAt: recording.createdAt,
      TransferMetadata.tag: recording.tag ?? "",
      TransferMetadata.duration: recording.duration,
      TransferMetadata.fileExtension: recording.fileURL.pathExtension
    ]

    WCSession.default.transferFile(recording.fileURL, metadata: metadata)
    pendingCleanupURLs.append(recording.fileURL)
    lastTransferDescription = "Queued \(recording.fileURL.lastPathComponent)"
  }
}

extension WatchConnectivityCoordinator: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}

  nonisolated func session(
    _ session: WCSession,
    didFinish fileTransfer: WCSessionFileTransfer,
    error: Error?
  ) {
    Task { @MainActor in
      if let error {
        lastTransferDescription = error.localizedDescription
        return
      }

      let fileURL = fileTransfer.file.fileURL
      if let index = pendingCleanupURLs.firstIndex(of: fileURL) {
        pendingCleanupURLs.remove(at: index)
      }
      try? FileManager.default.removeItem(at: fileURL)
      lastTransferDescription = "Transferred \(fileURL.lastPathComponent)"
    }
  }
}
