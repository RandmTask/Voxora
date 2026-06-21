import SwiftUI

struct ContentView: View {
  private enum AppTab: Hashable {
    case record
    case search
  }

  @Bindable var store: VoxoraStore
  @State private var selection: AppTab = .record

  var body: some View {
    TabView(selection: $selection) {
      Tab("Record", systemImage: "waveform", value: .record) {
        VoxoraHomeView(store: store)
      }

      Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
        TranscriptSearchView(store: store)
      }
    }
  }
}
