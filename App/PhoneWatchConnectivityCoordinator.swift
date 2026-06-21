import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchConnectivityCoordinator: NSObject {
  private weak var store: VoxoraStore?

  init(store: VoxoraStore) {
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
    sendPreferences()
  }

  func sendPreferences() {
    let behavior = UserDefaults.standard.string(
      forKey: AppPreferences.watchPrimaryButtonBehaviorKey
    )
      ?? PrimaryButtonBehavior.pause.rawValue
    try? WCSession.default.updateApplicationContext([
      AppPreferences.watchPrimaryButtonBehaviorKey: behavior
    ])
  }
}

extension PhoneWatchConnectivityCoordinator: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    didReceive file: WCSessionFile
  ) {
    let incomingURL = file.fileURL
    let metadata = file.metadata ?? [:]

    // WatchConnectivity owns the incoming URL only for the duration of this
    // callback. Stage it synchronously before hopping to the main actor.
    do {
      let noteID = UUID(uuidString: metadata[TransferMetadata.noteID] as? String ?? "") ?? UUID()
      let fileExtension = metadata[TransferMetadata.fileExtension] as? String ?? incomingURL.pathExtension
      let stagedURL = try AudioFileStore.copyAudioFile(
        from: incomingURL,
        noteID: noteID,
        fileExtension: fileExtension
      )
      Task { @MainActor [weak self] in
        self?.store?.ingestStagedAudio(fileURL: stagedURL, metadata: metadata)
      }
    } catch {
      Task { @MainActor [weak self] in
        self?.store?.errorMessage = "Watch transfer could not be saved: \(error.localizedDescription)"
      }
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
