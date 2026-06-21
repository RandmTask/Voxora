import SwiftUI

struct NoteActionsSheet: View {
  @Bindable var store: VoxoraStore
  @Bindable var note: AudioNote
  @Bindable var playback: AudioPlaybackController
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var transcriptionEngine: TranscriptionEngine = .appleSpeech
  @State private var isEmailing = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button {
            playback.toggle(note: note)
          } label: {
            Label(
              playback.playingNoteID == note.id ? "Stop audio" : "Play original audio",
              systemImage: playback.playingNoteID == note.id ? "stop.fill" : "play.fill"
            )
          }

          Picker("Transcription engine", selection: $transcriptionEngine) {
            ForEach(TranscriptionEngine.allCases) { engine in
              Text(engine.title).tag(engine)
            }
          }

          Button {
            Task { await store.retranscribe(note, using: transcriptionEngine) }
          } label: {
            Label("Retranscribe with \(transcriptionEngine.title)", systemImage: "waveform.badge.mic")
          }
          .disabled(note.duration < 1)
        } header: {
          Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
        } footer: {
          if note.duration < 1 {
            Text("Recordings shorter than one second cannot be reliably transcribed.")
          }
        }

        Section("Generate") {
          ForEach(store.prompts.filter(\.isEnabled)) { action in
            Button(action.title, systemImage: action.iconName) {
              Task {
                await store.runAction(action, on: note)
                dismiss()
              }
            }
          }
          Button("Email memo", systemImage: "envelope") {
            isEmailing = true
          }
        }
        .disabled(note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Section {
          Button(note.isFavorite ? "Remove Favorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star.fill") {
            store.toggleFavorite(note)
          }
          Button(note.archivedAt == nil ? "Archive" : "Unarchive", systemImage: "archivebox") {
            store.archive(note)
            dismiss()
          }
          Button("Delete Note", systemImage: "trash", role: .destructive) {
            onDelete()
          }
        }
      }
      .navigationTitle("Note Actions")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(isPresented: $isEmailing) {
        EmailWorkflowSheet(store: store, note: note)
      }
    }
  }
}
