import SwiftUI

struct ContentView: View {
  @Bindable var store: VoxoraStore

  var body: some View {
    VoxoraHomeView(store: store)
  }
}
