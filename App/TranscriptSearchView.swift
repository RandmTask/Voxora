import SwiftUI

struct TranscriptSearchView: View {
  @Bindable var store: VoxoraStore
  @State private var searchText = ""
  @State private var hideTooShort = true
  @State private var hideEmpty = true
  @State private var hideFailed = true
  @State private var isSearchPresented = false
  @State private var selectedTagIDs = Set<UUID>()

  private var hasQuery: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        if !hasQuery && selectedTagIDs.isEmpty {
          ContentUnavailableView(
            "Search transcripts",
            systemImage: "text.magnifyingglass",
            description: Text("Search titles, transcripts, generated outputs, and tags — or tap a tag to filter.")
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

  @ViewBuilder
  private var tagFilterStrip: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(store.sortedTags) { tag in
          let isActive = selectedTagIDs.contains(tag.id)
          Button {
            if isActive { selectedTagIDs.remove(tag.id) } else { selectedTagIDs.insert(tag.id) }
            Haptics.fire(.selectionChanged)
          } label: {
            TagPill(tag: tag, isActive: isActive)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
    }
    .scrollIndicators(.hidden)
  }

  private var results: [AudioNote] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard hasQuery || !selectedTagIDs.isEmpty else { return [] }
    return store.notes.filter { note in
      guard includes(note) else { return false }
      // Require every selected tag (AND), so "business + expense" narrows.
      if !selectedTagIDs.isEmpty {
        let noteTagIDs = Set(store.tags(for: note).map(\.id))
        guard selectedTagIDs.isSubset(of: noteTagIDs) else { return false }
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
