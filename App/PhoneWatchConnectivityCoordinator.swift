import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchConnectivityCoordinator: NSObject {
  private weak var store: VoiceSynapseStore?

  init(store: VoiceSynapseStore) {
    self.store = store
    super.init()
  }

  func activate() {
    guard WCSession.isSupported() else {
      return
    }

    let session = WCSession.default
    session.delegate = self
    session.activate()
  }
}

extension PhoneWatchConnectivityCoordinator: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    didReceive file: WCSessionFile
  ) {
    let fileURL = file.fileURL
    let metadata = file.metadata ?? [:]

    Task { @MainActor [weak self] in
      self?.store?.ingestTransferredAudio(fileURL: fileURL, metadata: metadata)
    }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }

  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}
}
