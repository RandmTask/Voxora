import SwiftUI

struct NoteEditorSheet: View {
  @Bindable var store: VoxoraStore
  var note: AudioNote

  @Environment(\.dismiss) private var dismiss
  @State private var transcript = ""
  @State private var output = ""
  @State private var title = ""
  @State private var newTag = ""
  @State private var selectedTagIDs = Set<UUID>()

  var body: some View {
    NavigationStack {
      Form {
        Section("Title") {
          TextField("Note title", text: $title)
        }

        Section("Tags") {
          ForEach(store.sortedTags) { tag in
            Toggle(isOn: Binding(
              get: { selectedTagIDs.contains(tag.id) },
              set: {
                if $0 {
                  selectedTagIDs.insert(tag.id)
                } else {
                  selectedTagIDs.remove(tag.id)
                }
              }
            )) {
              HStack(spacing: 8) {
                Circle()
                  .fill(Color(hex: tag.colorHex))
                  .frame(width: 10, height: 10)
                Text(tag.name)
              }
            }
          }

          HStack {
            TextField("New tag", text: $newTag)
            Button("Add") {
              let cleaned = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
              store.addTag(named: cleaned)
              if let tag = store.tags.first(where: {
                $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame
              }) {
                selectedTagIDs.insert(tag.id)
              }
              newTag = ""
            }
            .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }

        Section("Transcript") {
          TextEditor(text: $transcript)
            .frame(minHeight: 220)
        }

        Section("Generated output") {
          TextEditor(text: $output)
            .frame(minHeight: 180)
        }
      }
      .navigationTitle("Edit Note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            note.transcriptText = transcript
            note.transformedOutputText = output
            store.setTags(selectedTagIDs, on: note)
            store.persistChanges()
            dismiss()
          }
        }
      }
      .onAppear {
        title = note.title
        selectedTagIDs = Set(store.tags(for: note).map(\.id))
        transcript = note.transcriptText
        output = note.transformedOutputText
      }
    }
  }
}
