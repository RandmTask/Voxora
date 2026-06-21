import SwiftUI

struct VoxoraHomeView: View {
  @Bindable var store: VoxoraStore
  @State private var recorder = PhoneAudioRecorder()
  @State private var playback = AudioPlaybackController()
  @State private var isShowingSettings = false
  @State private var isPresentingMail = false
  @State private var actionNote: AudioNote?
  @State private var pendingDeleteNote: AudioNote?

  var body: some View {
    NavigationStack {
      ZStack {
        Color(red: 0.055, green: 0.06, blue: 0.1).ignoresSafeArea()

        ScrollView {
          VStack(spacing: 28) {
            recorderControl

            if store.notes.isEmpty {
              ContentUnavailableView(
                "No voice notes yet",
                systemImage: "waveform",
                description: Text("Record here or finish a recording on Apple Watch.")
              )
              .foregroundStyle(.secondary)
              .padding(.top, 24)
            } else {
              notesSection
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
        }
      }
      .navigationTitle("Voxora")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Settings", systemImage: "slider.horizontal.3") {
            isShowingSettings = true
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.glass)
        }
      }
      .sheet(isPresented: $isShowingSettings) {
        SettingsView(store: store)
      }
      .sheet(item: $actionNote) { note in
        NoteActionsSheet(
          store: store,
          note: note,
          playback: playback,
          onDelete: {
            actionNote = nil
            pendingDeleteNote = note
          }
        )
      }
      .sheet(isPresented: $isPresentingMail, onDismiss: store.dismissEmailDraft) {
        if let draft = store.pendingEmailDraft {
          MailComposerView(draft: draft, isPresented: $isPresentingMail)
        }
      }
      .alert("Voxora", isPresented: Binding(
        get: { store.errorMessage != nil || recorder.errorMessage != nil },
        set: {
          if !$0 {
            store.errorMessage = nil
            recorder.errorMessage = nil
          }
        }
      )) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(store.errorMessage ?? recorder.errorMessage ?? "")
      }
      .confirmationDialog(
        "Delete this voice note?",
        isPresented: Binding(
          get: { pendingDeleteNote != nil },
          set: { if !$0 { pendingDeleteNote = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Note", role: .destructive) {
          if let note = pendingDeleteNote {
            if playback.playingNoteID == note.id { playback.stop() }
            store.delete(note)
          }
          pendingDeleteNote = nil
        }
        Button("Cancel", role: .cancel) {
          pendingDeleteNote = nil
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var recorderControl: some View {
    VStack(spacing: 18) {
      Button(action: primaryRecorderAction) {
        ZStack {
          Circle()
            .stroke(Color.white.opacity(0.08), lineWidth: 18)
          Circle()
            .trim(from: 0, to: 0.985)
            .stroke(
              recorderColor,
              style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 7])
            )
            .rotationEffect(.degrees(-90))

          VStack(spacing: 8) {
            Image(systemName: recorderIcon)
              .font(.system(size: 34, weight: .bold))
            Text(recorderTitle)
              .font(.system(size: 28, weight: .black, design: .rounded))
            Text(recorderSubtitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            if recorder.state != .idle {
              Text(formattedDuration(recorder.elapsedTime))
                .font(.title3.monospacedDigit().weight(.semibold))
            }
          }
        }
        .frame(width: 285, height: 285)
        .contentShape(Circle())
      }
      .buttonStyle(.plain)

      if recorder.state == .recording || recorder.state == .paused {
        Button("End & transcribe", systemImage: "stop.fill") {
          finishPhoneRecording()
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      } else {
        Text("Record on iPhone or Apple Watch")
          .font(.footnote)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
  }

  private var notesSection: some View {
    LazyVStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent notes")
          .font(.title3.weight(.bold))
        Spacer()
        if store.isProcessing {
          ProgressView()
        }
      }

      ForEach(store.notes) { note in
        NavigationLink {
          TranscriptDetailView(store: store, note: note)
        } label: {
          AudioNoteCard(note: note, isPlaying: playback.playingNoteID == note.id)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.45)
            .onEnded { _ in actionNote = note }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
          Button("Delete", systemImage: "trash", role: .destructive) {
            pendingDeleteNote = note
          }
          Button("Generate", systemImage: "sparkles") {
            actionNote = note
          }
          .tint(.purple)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
          Button(
            playback.playingNoteID == note.id ? "Stop" : "Play",
            systemImage: playback.playingNoteID == note.id ? "stop.fill" : "play.fill"
          ) {
            playback.toggle(note: note)
          }
          .tint(.cyan)

          Button("Retranscribe", systemImage: "waveform.badge.mic") {
            Task { await store.retry(note) }
          }
          .tint(.indigo)
        }
      }
    }
  }

  private var recorderColor: Color {
    switch recorder.state {
    case .idle: .cyan
    case .recording: .red
    case .paused: .orange
    case .finalizing: .blue
    }
  }

  private var recorderTitle: String {
    switch recorder.state {
    case .idle: "START"
    case .recording: store.primaryButtonBehavior == .pause ? "PAUSE" : "SAVE"
    case .paused: "RESUME"
    case .finalizing: "SAVING"
    }
  }

  private var recorderSubtitle: String {
    switch recorder.state {
    case .idle: "Tap to record"
    case .recording: store.primaryButtonBehavior == .pause ? "Tap to pause" : "Tap to finish"
    case .paused: "Tap to continue"
    case .finalizing: "Preparing transcript"
    }
  }

  private var recorderIcon: String {
    switch recorder.state {
    case .idle: "mic.fill"
    case .recording: store.primaryButtonBehavior == .pause ? "pause.fill" : "checkmark"
    case .paused: "play.fill"
    case .finalizing: "waveform"
    }
  }

  private func primaryRecorderAction() {
    switch recorder.state {
    case .idle:
      Task {
        do { try await recorder.start() }
        catch { recorder.errorMessage = error.localizedDescription }
      }
    case .recording:
      if store.primaryButtonBehavior == .pause {
        recorder.pause()
      } else {
        finishPhoneRecording()
      }
    case .paused:
      recorder.resume()
    case .finalizing:
      break
    }
  }

  private func finishPhoneRecording() {
    do {
      let recording = try recorder.finish()
      store.ingestPhoneRecording(
        fileURL: recording.fileURL,
        noteID: recording.noteID,
        createdAt: recording.createdAt,
        duration: recording.duration
      )
    } catch {
      recorder.errorMessage = error.localizedDescription
    }
  }

  private func formattedDuration(_ duration: TimeInterval) -> String {
    String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60)
  }
}
