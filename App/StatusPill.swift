import SwiftUI

struct StatusPill: View {
  var title: String
  var systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.subheadline.weight(.semibold))
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .glassEffect(.clear, in: .capsule)
  }
}
