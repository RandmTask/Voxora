import SwiftData
import SwiftUI  

@main
struct VoxoraApp: App {
  @Environment(\.scenePhase) private var scenePhase

  private let container: ModelContainer
  private let store: VoxoraStore
  private let watchConnectivityCoordinator: PhoneWatchConnectivityCoordinator

  init() {
    do {
      container = try VoxoraPersistence.makeModelContainer()
    } catch {
      fatalError("Unable to create model container: \(error.localizedDescription)")
    }
    store = VoxoraStore(container: container)
    watchConnectivityCoordinator = PhoneWatchConnectivityCoordinator(store: store)
    store.preferenceSync = { [watchConnectivityCoordinator] in
      watchConnectivityCoordinator.sendPreferences()
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .task {
          watchConnectivityCoordinator.activate()
          await store.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
          guard phase == .active else { return }
          Task {
            await store.resumePendingImports()
          }
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
