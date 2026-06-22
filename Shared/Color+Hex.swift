import SwiftUI

extension Color {
  /// Builds a color from a `#RRGGBB` (or `RRGGBB`) hex string. Falls back to
  /// gray for malformed input so a bad value never crashes a tag pill.
  init(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)
    let red = Double((value & 0xFF0000) >> 16) / 255
    let green = Double((value & 0x00FF00) >> 8) / 255
    let blue = Double(value & 0x0000FF) / 255
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
  }
}

/// Curated tag colours, mirroring SteadyState's palette so Voxora tags share the
/// same look. Display names live in `TagPalette.name(for:)`.
enum TagPalette {
  static let colors: [String] = [
    "#7C5CFC", "#2563EB", "#0284C7", "#059669", "#16A34A",
    "#CA8A04", "#EA580C", "#DC2626", "#DB2777", "#9333EA",
    "#6B7280", "#1F2937"
  ]

  static let `default` = "#7C5CFC"

  static func name(for hex: String) -> String {
    switch hex.uppercased() {
    case "#7C5CFC": return "Violet"
    case "#2563EB": return "Blue"
    case "#0284C7": return "Sky"
    case "#059669": return "Emerald"
    case "#16A34A": return "Green"
    case "#CA8A04": return "Gold"
    case "#EA580C": return "Orange"
    case "#DC2626": return "Red"
    case "#DB2777": return "Pink"
    case "#9333EA": return "Purple"
    case "#6B7280": return "Gray"
    case "#1F2937": return "Charcoal"
    default: return "Custom"
    }
  }
}
