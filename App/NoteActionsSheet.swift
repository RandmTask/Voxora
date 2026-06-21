import SwiftUI

struct NoteActionsSheet: View {
  @Bindable var store: VoxoraStore
  @Bindable var note: AudioNote
  @Bindable var playback: AudioPlaybackController
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selectedProvider: AIProvider = .appleIntelligence
  @State private var transcriptionEngine: TranscriptionEngine = .appleSpeech

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

        Section("Generate with") {
          Picker("AI provider", selection: $selectedProvider) {
            ForEach(AIProvider.allCases) { provider in
              Text(provider.title).tag(provider)
            }
          }

          Button("Create to-do list", systemImage: "checklist") {
            generate(.todo)
          }
          Button("Create structured notes", systemImage: "list.bullet.rectangle") {
            generate(.bullets)
          }
          Button("Run custom action", systemImage: "wand.and.stars") {
            generate(.custom)
          }
        }
        .disabled(note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Section {
          Button("Archive", systemImage: "archivebox") {
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
    }
  }

  private func generate(_ kind: PromptKind) {
    Task {
      await store.transform(note, kind: kind, provider: selectedProvider)
      dismiss()
    }
  }
}
