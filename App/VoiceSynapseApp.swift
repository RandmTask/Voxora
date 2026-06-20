import SwiftData
import SwiftUI

@main
struct VoiceSynapseApp: App {
  private let container: ModelContainer
  private let store: VoiceSynapseStore
  private let watchConnectivityCoordinator: PhoneWatchConnectivityCoordinator

  init() {
    do {
      container = try VoiceSynapsePersistence.makeModelContainer()
    } catch {
      fatalError("Unable to create model container: \(error.localizedDescription)")
    }
    store = VoiceSynapseStore(container: container)
    watchConnectivityCoordinator = PhoneWatchConnectivityCoordinator(store: store)
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .task {
          watchConnectivityCoordinator.activate()
          await store.prepare()
        }
        .onOpenURL { url in
          guard let route = DeepLinkRoute(url: url) else {
            return
          }
          store.handle(route: route)
        }
    }
    .modelContainer(container)
  }
}
