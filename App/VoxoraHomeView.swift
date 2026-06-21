import SwiftUI
import UIKit

struct VoxoraHomeView: View {
  @Bindable var store: VoxoraStore
  @State private var recorder = PhoneAudioRecorder()
  @State private var playback = AudioPlaybackController()
  @State private var isShowingSettings = false
  @State private var actionNote: AudioNote?
  @State private var pendingDeleteNote: AudioNote?
  @State private var selectedNote: AudioNote?
  @State private var hideTooShort = true
  @State private var hideEmpty = true
  @State private var hideFailed = true
  @State private var showArchived = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color(red: 0.055, green: 0.06, blue: 0.1).ignoresSafeArea()

        List {
          recorderControl
            .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

          if store.notes.isEmpty {
            ContentUnavailableView(
              "No voice notes yet",
              systemImage: "waveform",
              description: Text("Record here or finish a recording on Apple Watch.")
            )
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
          } else if filteredNotes.isEmpty {
            ContentUnavailableView(
              "No visible notes",
              systemImage: "line.3.horizontal.decrease.circle",
              description: Text("Change the filters to show hidden recordings.")
            )
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
          } else {
            HStack {
              Text("Recent notes")
                .font(.title3.weight(.bold))
              Spacer()
              if store.isProcessing {
                ProgressView()
              }
            }
            .padding(.top, 8)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
            .listRowBackground(Color(red: 0.055, green: 0.06, blue: 0.1).opacity(0.96))
            .listRowSeparator(.hidden)

            ForEach(filteredNotes) { note in
              noteRow(note)
            }
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
      }
      .navigationTitle("Voxora")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Menu {
            Toggle("Hide too short", isOn: $hideTooShort)
            Toggle("Hide empty", isOn: $hideEmpty)
            Toggle("Hide failed", isOn: $hideFailed)
            Toggle("Show archived", isOn: $showArchived)
          } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.glass)

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
      .navigationDestination(item: $selectedNote) { note in
        TranscriptDetailView(store: store, note: note)
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

  private var filteredNotes: [AudioNote] {
    store.notes.filter { note in
      includes(note)
    }
    .sorted {
      if $0.isFavorite != $1.isFavorite {
        return $0.isFavorite && !$1.isFavorite
      }
      return $0.timestamp > $1.timestamp
    }
  }

  private var filtersAreActive: Bool {
    hideTooShort || hideEmpty || hideFailed || !showArchived
  }

  private func includes(_ note: AudioNote) -> Bool {
    if hideTooShort && note.processingStatus == .tooShort { return false }
    if hideEmpty && note.processingStatus == .empty { return false }
    if hideFailed && note.processingStatus == .failed { return false }
    if !showArchived && note.archivedAt != nil { return false }
    return true
  }

  private var recorderControl: some View {
    VStack(spacing: 18) {
      if recorder.state == .idle {
        Button(action: primaryRecorderAction) {
          VStack(spacing: 12) {
            HStack(spacing: 10) {
              Image(systemName: "mic.fill")
                .font(.system(size: 30, weight: .semibold))
              Text("Start recording")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            }
          }
          .frame(maxWidth: .infinity)
          .frame(height: 190)
          .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
              .fill(Color.cyan.opacity(0.14))
              .stroke(Color.cyan.opacity(0.75), lineWidth: 2)
          }
          .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
      } else {
        VStack(spacing: 12) {
          Text(formattedDuration(recorder.elapsedTime))
            .font(.title2.monospacedDigit().weight(.semibold))

          RecordingMeterView(samples: recorder.meterSamples, color: recorderColor)
            .frame(height: 64)

          if recorder.state == .finalizing {
            ProgressView("Preparing transcript")
          } else {
            HStack(spacing: 26) {
              if store.phonePrimaryButtonBehavior == .pause {
                Button {
                  if recorder.state == .paused {
                    recorder.resume()
                  } else {
                    recorder.pause()
                  }
                } label: {
                  Image(systemName: recorder.state == .paused ? "play.fill" : "pause.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(recorder.state == .paused ? "Resume recording" : "Pause recording")
              }

              Button {
                finishPhoneRecording()
              } label: {
                Image(systemName: "stop.fill")
                  .font(.system(size: 18, weight: .bold))
                  .foregroundStyle(.white)
                  .frame(width: 52, height: 52)
                  .background(.red, in: Circle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Stop and transcribe")
            }
          }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 190)
        .background {
          RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(recorderColor.opacity(0.14))
            .stroke(recorderColor.opacity(0.75), lineWidth: 2)
        }
      }

      if recorder.state == .idle {
        Text("Record on iPhone or Apple Watch")
          .font(.footnote)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
  }

  private func noteRow(_ note: AudioNote) -> some View {
    Button {
      selectedNote = note
    } label: {
      AudioNoteCard(note: note, isPlaying: playback.playingNoteID == note.id)
    }
    .buttonStyle(.plain)
    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Delete", systemImage: "trash") {
        requestDelete(note)
      }
      .tint(.red)
      Button("Generate", systemImage: "sparkles") {
        actionNote = note
      }
      .tint(.purple)
      Button("Copy Transcript", systemImage: "doc.on.doc") {
        UIPasteboard.general.string = note.transcriptText
      }
      .disabled(note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      Button(note.isFavorite ? "Unfavorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star.fill") {
        store.toggleFavorite(note)
      }
      .tint(.yellow)
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
    .contextMenu {
      Button(
        playback.playingNoteID == note.id ? "Stop Audio" : "Play Audio",
        systemImage: playback.playingNoteID == note.id ? "stop.fill" : "play.fill"
      ) {
        playback.toggle(note: note)
      }
      Button("Retranscribe", systemImage: "waveform.badge.mic") {
        Task { await store.retry(note) }
      }
      Button("Generate", systemImage: "sparkles") {
        actionNote = note
      }
      Button(note.isFavorite ? "Unfavorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star.fill") {
        store.toggleFavorite(note)
      }
      Button("Delete Note", systemImage: "trash", role: .destructive) {
        requestDelete(note)
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

  private func primaryRecorderAction() {
    switch recorder.state {
    case .idle:
      Task {
        do { try await recorder.start() }
        catch { recorder.errorMessage = error.localizedDescription }
      }
    case .recording:
      if store.phonePrimaryButtonBehavior == .pause {
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

  private func requestDelete(_ note: AudioNote) {
    pendingDeleteNote = note
  }
}

private struct RecordingMeterView: View {
  let samples: [CGFloat]
  let color: Color

  var body: some View {
    HStack(alignment: .center, spacing: 3) {
      ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
        Capsule()
          .fill(color.gradient)
          .frame(maxWidth: .infinity)
          .frame(height: max(5, sample * 58))
      }
    }
    .animation(.linear(duration: 0.16), value: samples)
    .accessibilityHidden(true)
  }
}
