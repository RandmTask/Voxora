import SwiftUI

struct ContentView: View {
  @Bindable var store: VoiceSynapseStore

  var body: some View {
    VoiceSynapseHomeView(store: store)
  }
}
