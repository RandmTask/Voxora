import SwiftUI

struct TranscriptSearchView: View {
  @Bindable var store: VoxoraStore
  @State private var searchText = ""
  @State private var hideTooShort = true
  @State private var hideEmpty = true
  @State private var hideFailed = true
  @State private var isSearchPresented = false

  var body: some View {
    NavigationStack {
      List {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          ContentUnavailableView(
            "Search transcripts",
            systemImage: "text.magnifyingglass",
            description: Text("Search titles, transcripts, generated outputs, and tags.")
          )
          .listRowBackground(Color.clear)
        } else if results.isEmpty {
          ContentUnavailableView.search(text: searchText)
            .listRowBackground(Color.clear)
        } else {
          ForEach(results) { note in
            NavigationLink {
              TranscriptDetailView(store: store, note: note)
            } label: {
              AudioNoteCard(note: note)
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

  private var results: [AudioNote] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }
    return store.notes.filter { note in
      includes(note)
        && [
          note.title,
          note.transcriptText,
          note.transformedOutputText,
          store.tags(for: note).map(\.name).joined(separator: " ")
        ]
        .joined(separator: "\n")
        .localizedCaseInsensitiveContains(query)
    }
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
