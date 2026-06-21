import SwiftData
import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

enum VoxoraTheme {
  static let page = dynamic(
    light: (0.95, 0.96, 0.98),
    dark: (0.055, 0.06, 0.1)
  )
  static let detailGradientTop = dynamic(
    light: (0.84, 0.92, 0.98),
    dark: (0.04, 0.08, 0.16)
  )
  static let detailGradientMiddle = dynamic(
    light: (0.91, 0.96, 0.99),
    dark: (0.12, 0.28, 0.43)
  )
  static let detailGradientBottom = dynamic(
    light: (0.98, 0.99, 1.0),
    dark: (0.84, 0.92, 0.98)
  )

  private static func dynamic(
    light: (Double, Double, Double),
    dark: (Double, Double, Double)
  ) -> Color {
    Color(UIColor { traits in
      let components = traits.userInterfaceStyle == .dark ? dark : light
      return UIColor(
        red: components.0,
        green: components.1,
        blue: components.2,
        alpha: 1
      )
    })
  }
}

@main
struct VoxoraApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(AppPreferences.appearanceKey) private var appearanceRawValue = AppTheme.dark.rawValue

  private let container: ModelContainer
  private let store: VoxoraStore
  private let watchConnectivityCoordinator: PhoneWatchConnectivityCoordinator

  private var appearance: AppTheme {
    AppTheme(rawValue: appearanceRawValue) ?? .dark
  }

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
        .preferredColorScheme(appearance.colorScheme)
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
