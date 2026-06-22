import SwiftUI

/// A coloured tag pill, SteadyState-style: a tinted capsule with a leading dot.
/// Used on note cards (`isCompact`) and in the home filter strip (`isActive`).
struct TagPill: View {
  let tag: NoteTag
  var isActive = false
  var isCompact = false

  private var color: Color { Color(hex: tag.colorHex) }

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(isActive ? Color.white : color)
        .frame(width: isCompact ? 6 : 7, height: isCompact ? 6 : 7)
      Text(tag.name)
        .font(isCompact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        .lineLimit(1)
    }
    .padding(.horizontal, isCompact ? 9 : 12)
    .padding(.vertical, isCompact ? 4 : 7)
    .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(color))
    .background(
      isActive ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.16)),
      in: Capsule()
    )
  }
}

/// One row in the Tags manage list: colour swatch, name, count badge, and
/// pin/rename/delete via swipe or context menu. Mirrors SteadyState's manage row.
struct TagManageRow: View {
  let tag: NoteTag
  let count: Int
  let onColor: (String) -> Void
  let onPin: () -> Void
  let onRename: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TagColorSwatchPicker(selectedHex: Binding(get: { tag.colorHex }, set: onColor))

      if tag.isPinned {
        Image(systemName: "pin.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text(tag.name)
        .font(.body)
        .lineLimit(1)

      Spacer()

      if count > 0 {
        Text("\(count)")
          .font(.caption.weight(.medium))
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(.quaternary, in: Capsule())
          .foregroundStyle(.secondary)
      }
    }
    .contextMenu {
      Button(tag.isPinned ? "Unpin" : "Pin", systemImage: tag.isPinned ? "pin.slash" : "pin", action: onPin)
      Button("Rename", systemImage: "pencil", action: onRename)
      Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
      Button("Rename", systemImage: "pencil", action: onRename)
        .tint(.orange)
      Button(tag.isPinned ? "Unpin" : "Pin", systemImage: tag.isPinned ? "pin.slash" : "pin", action: onPin)
        .tint(.indigo)
    }
  }
}

/// A circular colour swatch that opens a palette popover. Mirrors SteadyState's
/// `ColorSwatchPicker`.
struct TagColorSwatchPicker: View {
  @Binding var selectedHex: String
  @State private var isShowingPalette = false

  var body: some View {
    Button {
      isShowingPalette = true
    } label: {
      Circle()
        .fill(Color(hex: selectedHex))
        .frame(width: 22, height: 22)
        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
        .frame(width: 30, height: 30)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $isShowingPalette, arrowEdge: .bottom) {
      paletteGrid
        .presentationCompactAdaptation(.popover)
    }
    .accessibilityLabel("Tag colour")
  }

  private var paletteGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 10), count: 4), spacing: 10) {
      ForEach(TagPalette.colors, id: \.self) { hex in
        Button {
          selectedHex = hex
          isShowingPalette = false
        } label: {
          Circle()
            .fill(Color(hex: hex))
            .frame(width: 28, height: 28)
            .overlay {
              if hex.caseInsensitiveCompare(selectedHex) == .orderedSame {
                Image(systemName: "checkmark")
                  .font(.caption.weight(.bold))
                  .foregroundStyle(.white)
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(16)
  }
}
