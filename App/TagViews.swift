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

/// A wrapping horizontal flow layout (word-wrap for chips).
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        y += lineHeight + spacing
        x = 0
        lineHeight = 0
      }
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    return CGSize(width: maxWidth, height: max(y + lineHeight, 0))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        y += lineHeight + spacing
        x = bounds.minX
        lineHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
  }
}

/// SteadyState-style tag editor: selected tags shown as removable chips, with a
/// "+ Add Tag" button opening a popover that lists all tags (checkmarked when
/// selected) and an inline create field that picks a fresh colour automatically.
struct TagFlowEditor: View {
  @Bindable var store: VoxoraStore
  @Binding var selectedTagIDs: Set<UUID>

  @State private var showPopover = false
  @State private var newTagName = ""
  @State private var newTagColor = TagPalette.default
  @FocusState private var fieldFocused: Bool

  private var selectedTags: [NoteTag] {
    store.sortedTags.filter { selectedTagIDs.contains($0.id) }
  }

  var body: some View {
    FlowLayout(spacing: 8) {
      ForEach(selectedTags) { tag in
        chip(tag)
      }
      addButton
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    // Anchor the popover to the whole Tags row, not the "+ Add Tag" button:
    // adding a chip shifts the button but leaves the row's frame stable, so the
    // popover no longer jumps around as tags are created.
    .popover(isPresented: $showPopover, arrowEdge: .bottom) {
      popoverContent
        .presentationCompactAdaptation(.popover)
    }
    .onChange(of: showPopover) { _, shown in
      if !shown { newTagName = "" }
    }
  }

  private func chip(_ tag: NoteTag) -> some View {
    let color = Color(hex: tag.colorHex)
    return HStack(spacing: 5) {
      Text(tag.name)
        .font(.subheadline.weight(.semibold))
      Button {
        selectedTagIDs.remove(tag.id)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 7)
    .foregroundStyle(color)
    .background(color.opacity(0.16), in: Capsule())
  }

  private var addButton: some View {
    Button {
      newTagColor = store.nextUnusedTagColor()
      showPopover = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
        Text("Add Tag").font(.subheadline.weight(.semibold))
      }
      .padding(.horizontal, 11)
      .padding(.vertical, 7)
      .foregroundStyle(.secondary)
      .background(.quaternary, in: Capsule())
    }
    .buttonStyle(.plain)
  }

  private var popoverContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        TagColorSwatchPicker(selectedHex: $newTagColor)
        TextField("New tag name…", text: $newTagName)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($fieldFocused)
          .onSubmit(createTag)
        if !newTagName.trimmingCharacters(in: .whitespaces).isEmpty {
          Button("Add", action: createTag)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(16)

      Divider()

      if store.tags.isEmpty {
        Text("No tags yet — type a name above to create one.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(16)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(store.sortedTags) { tag in
              tagRow(tag)
            }
          }
          .padding(.vertical, 6)
        }
        .frame(maxHeight: 300)
      }
    }
    .frame(width: 300)
  }

  private func tagRow(_ tag: NoteTag) -> some View {
    let isSelected = selectedTagIDs.contains(tag.id)
    return Button {
      if isSelected {
        selectedTagIDs.remove(tag.id)
      } else {
        selectedTagIDs.insert(tag.id)
      }
    } label: {
      HStack(spacing: 10) {
        Circle()
          .fill(Color(hex: tag.colorHex))
          .frame(width: 11, height: 11)
        Text(tag.name)
          .font(.body)
          .foregroundStyle(.primary)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 9)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func createTag() {
    guard let tag = store.upsertTag(named: newTagName, colorHex: newTagColor) else { return }
    selectedTagIDs.insert(tag.id)
    newTagName = ""
    newTagColor = store.nextUnusedTagColor()
  }
}

/// Sheet for assigning tags to one or many notes, reusing `TagFlowEditor`.
/// - Single note: pre-selects its current tags and saves the exact set (add + remove).
/// - Multiple notes: starts empty and *adds* the chosen tags to every note (never
///   removes), so batch-tagging can't strip tags a note already had.
struct TagAssignmentSheet: View {
  @Bindable var store: VoxoraStore
  let notes: [AudioNote]

  @Environment(\.dismiss) private var dismiss
  @State private var selectedTagIDs = Set<UUID>()

  private var isSingle: Bool { notes.count == 1 }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TagFlowEditor(store: store, selectedTagIDs: $selectedTagIDs)
        } header: {
          Text("Tags")
        } footer: {
          if !isSingle {
            Text("These tags are added to all \(notes.count) selected notes.")
          }
        }
      }
      .navigationTitle(isSingle ? "Tags" : "Tag \(notes.count) Notes")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .fontWeight(.semibold)
        }
      }
      .onAppear {
        if isSingle {
          selectedTagIDs = Set(store.tags(for: notes[0]).map(\.id))
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func save() {
    if isSingle {
      store.setTags(selectedTagIDs, on: notes[0])
    } else {
      let selected = store.sortedTags.filter { selectedTagIDs.contains($0.id) }
      for note in notes {
        for tag in selected {
          store.setTag(tag, on: note, isAssigned: true)
        }
      }
    }
    Haptics.fire(.light)
    dismiss()
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
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 14), count: 5), spacing: 14) {
      ForEach(TagPalette.colors, id: \.self) { hex in
        Button {
          selectedHex = hex
          isShowingPalette = false
        } label: {
          Circle()
            .fill(Color(hex: hex))
            .frame(width: 30, height: 30)
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
    .padding(22)
  }
}
