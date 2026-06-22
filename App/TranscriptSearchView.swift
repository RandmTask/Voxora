import SwiftUI

struct TranscriptSearchView: View {
  @Bindable var store: VoxoraStore
  @State private var searchText = ""
  @State private var hideTooShort = true
  @State private var hideEmpty = true
  @State private var hideFailed = true
  @State private var isSearchPresented = false
  @State private var selectedTagIDs = Set<UUID>()

  /// `#tag` tokens typed into the search field, lowercased without the `#`.
  private var typedTagTokens: [String] {
    searchText
      .split(whereSeparator: { $0 == " " || $0 == "\n" })
      .filter { $0.hasPrefix("#") && $0.count > 1 }
      .map { String($0.dropFirst()).lowercased() }
  }

  /// Tags whose name matches a typed `#tag` token.
  private var typedTagIDs: Set<UUID> {
    let tokens = typedTagTokens
    guard !tokens.isEmpty else { return [] }
    return Set(
      store.tags
        .filter { tag in tokens.contains { tag.name.localizedCaseInsensitiveCompare($0) == .orderedSame } }
        .map(\.id)
    )
  }

  /// Tapped pills ∪ typed `#tags`.
  private var effectiveTagIDs: Set<UUID> {
    selectedTagIDs.union(typedTagIDs)
  }

  /// Search text with the `#tag` tokens stripped out — the free-text query.
  private var freeQuery: String {
    searchText
      .split(whereSeparator: { $0 == " " || $0 == "\n" })
      .filter { !$0.hasPrefix("#") }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    NavigationStack {
      List {
        if !store.tags.isEmpty {
          tagFilterStrip
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }

        if freeQuery.isEmpty && effectiveTagIDs.isEmpty {
          ContentUnavailableView(
            "Search transcripts",
            systemImage: "text.magnifyingglass",
            description: Text("Search titles, transcripts and outputs, tap a tag, or type #tag to filter.")
          )
          .listRowBackground(Color.clear)
        } else if results.isEmpty {
          ContentUnavailableView(
            "No matches",
            systemImage: "magnifyingglass",
            description: Text("Try a different search or tag combination.")
          )
          .listRowBackground(Color.clear)
        } else {
          ForEach(results) { note in
            NavigationLink {
              TranscriptDetailView(store: store, note: note)
            } label: {
              AudioNoteCard(note: note, tags: store.tags(for: note))
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.immediately)
      .simultaneousGesture(
        TapGesture().onEnded {
          isSearchPresented = false
        }
      )
      .background(VoxoraTheme.page)
      .onAppear { store.refreshSearchTagOrderIfNeeded() }
      .navigationTitle("Search")
      .searchable(
        text: $searchText,
        isPresented: $isSearchPresented,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search transcripts"
      )
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          exclusionFilterMenu
        }
      }
    }
  }

  // A "sea of tags": wraps left-to-right into as many rows as it needs (1, 2, 3…),
  // most-used first. The list itself scrolls when there are a lot of tags.
  private var tagFilterStrip: some View {
    FlowLayout(spacing: 8) {
      ForEach(store.searchOrderedTags) { tag in
        let isActive = effectiveTagIDs.contains(tag.id)
        Button {
          if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
          } else {
            selectedTagIDs.insert(tag.id)
          }
          Haptics.fire(.selectionChanged)
        } label: {
          TagPill(tag: tag, isActive: isActive)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 20)
  }

  private var results: [AudioNote] {
    let tagIDs = effectiveTagIDs
    let query = freeQuery
    guard !query.isEmpty || !tagIDs.isEmpty else { return [] }
    return store.notes.filter { note in
      guard includes(note) else { return false }
      // Require every selected/typed tag (AND), so "#business #expense" narrows.
      if !tagIDs.isEmpty {
        let noteTagIDs = Set(store.tags(for: note).map(\.id))
        guard tagIDs.isSubset(of: noteTagIDs) else { return false }
      }
      guard !query.isEmpty else { return true }
      return [
        note.title,
        note.transcriptText,
        note.transformedOutputText,
        store.tags(for: note).map(\.name).joined(separator: " ")
      ]
      .joined(separator: "\n")
      .localizedCaseInsensitiveContains(query)
    }
    .sorted { $0.timestamp > $1.timestamp }
  }

  private var exclusionFilterMenu: some View {
    Menu {
      Toggle("Hide too short", isOn: $hideTooShort)
      Toggle("Hide empty", isOn: $hideEmpty)
      Toggle("Hide failed", isOn: $hideFailed)
    } label: {
      Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
    }
  }

  private func includes(_ note: AudioNote) -> Bool {
    if hideTooShort && note.displayedProcessingStatus == .tooShort { return false }
    if hideEmpty && note.displayedProcessingStatus == .empty { return false }
    if hideFailed && note.displayedProcessingStatus == .failed { return false }
    return true
  }
}
