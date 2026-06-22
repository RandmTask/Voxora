import Foundation

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

@MainActor
enum Haptics {
  enum FeedbackType {
    case success, warning, error, light, medium, heavy, selectionChanged, start, stop
  }

  static func fire(_ type: FeedbackType) {
    #if os(iOS)
    switch type {
    case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
    case .light, .stop: UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium, .start: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .selectionChanged: UISelectionFeedbackGenerator().selectionChanged()
    }
    #elseif os(watchOS)
    switch type {
    case .success: WKInterfaceDevice.current().play(.success)
    case .warning: WKInterfaceDevice.current().play(.notification)
    case .error: WKInterfaceDevice.current().play(.failure)
    case .light, .selectionChanged: WKInterfaceDevice.current().play(.click)
    case .medium: WKInterfaceDevice.current().play(.click)
    case .heavy: WKInterfaceDevice.current().play(.notification)
    case .start: WKInterfaceDevice.current().play(.start)
    case .stop: WKInterfaceDevice.current().play(.stop)
    }
    #endif
  }
}
