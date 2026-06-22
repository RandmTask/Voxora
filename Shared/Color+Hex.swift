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
    "#7C5CFC", "#4F46E5", "#2563EB", "#0284C7", "#0891B2",
    "#0D9488", "#059669", "#16A34A", "#65A30D", "#CA8A04",
    "#D97706", "#EA580C", "#DC2626", "#E11D48", "#DB2777",
    "#C026D3", "#9333EA", "#475569", "#6B7280", "#1F2937"
  ]

  static let `default` = "#7C5CFC"

  static func name(for hex: String) -> String {
    switch hex.uppercased() {
    case "#7C5CFC": return "Violet"
    case "#4F46E5": return "Indigo"
    case "#2563EB": return "Blue"
    case "#0284C7": return "Sky"
    case "#0891B2": return "Cyan"
    case "#0D9488": return "Teal"
    case "#059669": return "Emerald"
    case "#16A34A": return "Green"
    case "#65A30D": return "Lime"
    case "#CA8A04": return "Gold"
    case "#D97706": return "Amber"
    case "#EA580C": return "Orange"
    case "#DC2626": return "Red"
    case "#E11D48": return "Rose"
    case "#DB2777": return "Pink"
    case "#C026D3": return "Fuchsia"
    case "#9333EA": return "Purple"
    case "#475569": return "Slate"
    case "#6B7280": return "Gray"
    case "#1F2937": return "Charcoal"
    default: return "Custom"
    }
  }
}
