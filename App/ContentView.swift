import SwiftUI

struct ContentView: View {
  @Bindable var store: VoxoraStore

  var body: some View {
    TabView {
      VoxoraHomeView(store: store)
        .tabItem {
          Label("Record", systemImage: "waveform")
        }

      TranscriptSearchView(store: store)
        .tabItem {
          Label("Search", systemImage: "magnifyingglass")
        }
    }
  }
}
