import SwiftUI

@main
struct VoxoraWatchApp: App {
  private let audioEngineManager = WatchAudioEngineManager()
  private let connectivityCoordinator = WatchConnectivityCoordinator()

  init() {
    connectivityCoordinator.activate()
  }

  var body: some Scene {
    WindowGroup {
      ContentView(
        audioEngineManager: audioEngineManager,
        connectivityCoordinator: connectivityCoordinator
      )
      .onOpenURL { url in
        guard let route = DeepLinkRoute(url: url) else {
          return
        }

        if route == .record {
          Task {
            try? await audioEngineManager.startOrResumeRecording()
          }
        }
      }
    }
  }
}
