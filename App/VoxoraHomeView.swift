import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct VoxoraHomeView: View {
  @Bindable var store: VoxoraStore
  @State private var recorder = PhoneAudioRecorder()
  @State private var playback = AudioPlaybackController()
  @State private var isShowingSettings = false
  @State private var isImporting = false
  @State private var isSelecting = false
  @State private var selectedIDs = Set<UUID>()
  @State private var pendingBatchDelete = false
  @State private var shareItems: [Any]?
  @State private var batchEmailDraft: EmailDraft?
  @State private var activeTagFilter: UUID?
  @Environment(\.colorScheme) private var systemColorScheme
  @State private var actionNote: AudioNote?
  @State private var emailNote: AudioNote?
  @State private var pendingDeleteNote: AudioNote?
  @State private var selectedNote: AudioNote?
  @AppStorage(AppPreferences.hideUnusableNotesKey) private var hideUnusable = true
  @AppStorage(AppPreferences.hideFailedNotesKey) private var hideFailed = true
  @AppStorage(AppPreferences.showArchivedNotesKey) private var showArchived = false
  @AppStorage(AppPreferences.appearanceKey) private var appearanceRawValue = AppTheme.dark.rawValue

  private var appearance: AppTheme {
    AppTheme(rawValue: appearanceRawValue) ?? .dark
  }

  var body: some View {
    NavigationStack {
      ZStack {
        VoxoraTheme.page.ignoresSafeArea()

        List {
          if !isSelecting {
            recorderControl
              .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
          }

          if !isSelecting && !store.notes.isEmpty && !store.tags.isEmpty {
            tagFilterStrip
              .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 6, trailing: 0))
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
          }

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
              Text(isSelecting ? selectionHeaderText : "Recent notes")
                .font(.title3.weight(.bold))
              Spacer()
              if store.isProcessing {
                ProgressView()
              }
            }
            .padding(.top, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            .listRowBackground(VoxoraTheme.page.opacity(0.96))
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
        if isSelecting {
          ToolbarItem(placement: .topBarLeading) {
            Button(selectedIDs.count == filteredNotes.count ? "Deselect All" : "Select All") {
              if selectedIDs.count == filteredNotes.count {
                selectedIDs.removeAll()
              } else {
                selectedIDs = Set(filteredNotes.map(\.id))
              }
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
              exitSelection()
            }
            .fontWeight(.semibold)
          }
        } else {
          ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
              Section {
                Toggle("Hide unusable", isOn: $hideUnusable)
                Toggle("Hide failed", isOn: $hideFailed)
                Toggle("Show archived", isOn: $showArchived)
              }
              Section {
                Button("Select Notes", systemImage: "checkmark.circle") {
                  isSelecting = true
                }
                Button("Import Audio", systemImage: "square.and.arrow.down") {
                  isImporting = true
                }
              }
            } label: {
              Label("Options", systemImage: "ellipsis.circle")
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
      }
      .safeAreaInset(edge: .bottom) {
        if isSelecting {
          selectionActionBar
        }
      }
      .fileImporter(
        isPresented: $isImporting,
        allowedContentTypes: [.audio],
        allowsMultipleSelection: true
      ) { result in
        switch result {
        case .success(let urls):
          Task { await store.importAudioFiles(urls) }
        case .failure(let error):
          store.errorMessage = error.localizedDescription
        }
      }
      .sheet(isPresented: $isShowingSettings) {
        SettingsView(store: store)
          .preferredColorScheme(appearance.colorScheme ?? systemColorScheme)
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
      .sheet(item: $emailNote) { note in
        EmailWorkflowSheet(store: store, note: note)
      }
      .sheet(item: $batchEmailDraft) { draft in
        MailComposerView(draft: draft) {
          batchEmailDraft = nil
          exitSelection()
        }
        .ignoresSafeArea()
      }
      .sheet(isPresented: Binding(
        get: { shareItems != nil },
        set: { if !$0 { shareItems = nil } }
      )) {
        if let shareItems {
          ActivityView(items: shareItems)
        }
      }
      .alert(
        "Delete \(selectedIDs.count) \(selectedIDs.count == 1 ? "note" : "notes")?",
        isPresented: $pendingBatchDelete
      ) {
        Button("Delete", role: .destructive) { performBatchDelete() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This permanently deletes the recordings, transcripts, and generated outputs.")
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
      .alert(
        "Delete voice note?",
        isPresented: Binding(
          get: { pendingDeleteNote != nil },
          set: { if !$0 { pendingDeleteNote = nil } }
        )
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
      } message: {
        Text("This permanently deletes the recording, transcript, and generated outputs.")
      }
    }
    .onAppear {
      handlePendingRoute()
    }
    .onChange(of: store.selectedRoute) { _, _ in
      handlePendingRoute()
    }
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

  private func includes(_ note: AudioNote) -> Bool {
    let status = note.displayedProcessingStatus
    if hideUnusable && (status == .tooShort || status == .empty) {
      return false
    }
    if hideFailed && status == .failed { return false }
    if !showArchived && note.archivedAt != nil { return false }
    if let activeTagFilter,
       !store.tags(for: note).contains(where: { $0.id == activeTagFilter }) {
      return false
    }
    return true
  }

  @ViewBuilder
  private var tagFilterStrip: some View {
    if !store.tags.isEmpty {
      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          ForEach(store.tags) { tag in
            let isActive = activeTagFilter == tag.id
            Button {
              activeTagFilter = isActive ? nil : tag.id
              Haptics.fire(.selectionChanged)
            } label: {
              Label(tag.name, systemImage: "tag")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(
              isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
              in: Capsule()
            )
            .foregroundStyle(isActive ? .white : .primary)
          }
        }
        .padding(.horizontal, 20)
      }
      .scrollIndicators(.hidden)
    }
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

    }
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
  }

  private func noteRow(_ note: AudioNote) -> some View {
    Button {
      if isSelecting {
        toggleSelection(note)
      } else {
        selectedNote = note
      }
    } label: {
      HStack(spacing: 10) {
        if isSelecting {
          Image(systemName: selectedIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(selectedIDs.contains(note.id) ? Color.accentColor : .secondary)
            .transition(.scale.combined(with: .opacity))
        }
        AudioNoteCard(note: note, isPlaying: playback.playingNoteID == note.id)
      }
    }
    .buttonStyle(.plain)
    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button("Delete", systemImage: "trash", role: .destructive) {
        requestDelete(note)
      }
      .tint(.red)
      Button("Generate", systemImage: "sparkles") {
        actionNote = note
      }
      .tint(.purple)
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
      Button("Copy Transcript", systemImage: "doc.on.doc") {
        UIPasteboard.general.string = note.transcriptText
      }
      .disabled(note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      Button("Email Memo", systemImage: "envelope") {
        emailNote = note
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
      Haptics.fire(.start)
      Task {
        do { try await recorder.start() }
        catch { recorder.errorMessage = error.localizedDescription }
      }
    case .recording:
      if store.phonePrimaryButtonBehavior == .pause {
        Haptics.fire(.light)
        recorder.pause()
      } else {
        finishPhoneRecording()
      }
    case .paused:
      Haptics.fire(.light)
      recorder.resume()
    case .finalizing:
      break
    }
  }

  private func handlePendingRoute() {
    guard store.selectedRoute == .record else {
      return
    }

    store.selectedRoute = nil
    guard recorder.state == .idle else {
      return
    }

    Task {
      do {
        try await recorder.start()
      } catch {
        recorder.errorMessage = error.localizedDescription
      }
    }
  }

  private func finishPhoneRecording() {
    do {
      Haptics.fire(.stop)
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

  // MARK: - Multi-select

  private var selectionHeaderText: String {
    selectedIDs.isEmpty ? "Select notes" : "\(selectedIDs.count) selected"
  }

  private var selectionActionBar: some View {
    HStack(spacing: 0) {
      selectionAction("Delete", systemImage: "trash", tint: .red) {
        pendingBatchDelete = true
      }
      selectionAction("Export", systemImage: "square.and.arrow.up") {
        exportSelection()
      }
      selectionAction("Email", systemImage: "envelope") {
        emailSelection()
      }
    }
    .padding(.vertical, 10)
    .background(.bar)
    .disabled(selectedIDs.isEmpty)
    .animation(.easeInOut, value: selectedIDs.isEmpty)
  }

  private func selectionAction(
    _ title: String,
    systemImage: String,
    tint: Color = .accentColor,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: systemImage)
          .font(.title3)
        Text(title)
          .font(.caption2)
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(selectedIDs.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
    }
  }

  private var selectedNotes: [AudioNote] {
    store.notes.filter { selectedIDs.contains($0.id) }
      .sorted { $0.timestamp < $1.timestamp }
  }

  private func toggleSelection(_ note: AudioNote) {
    if selectedIDs.contains(note.id) {
      selectedIDs.remove(note.id)
    } else {
      selectedIDs.insert(note.id)
    }
    Haptics.fire(.selectionChanged)
  }

  private func exitSelection() {
    isSelecting = false
    selectedIDs.removeAll()
  }

  private func performBatchDelete() {
    for note in selectedNotes {
      if playback.playingNoteID == note.id { playback.stop() }
      store.delete(note)
    }
    exitSelection()
  }

  private func combinedText(for notes: [AudioNote]) -> String {
    notes.map { note in
      var parts = ["# \(note.displayTitle)"]
      if store.includeTimestampInExports {
        parts.append(note.timestamp.formatted(date: .abbreviated, time: .shortened))
      }
      let transcript = note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
      if !transcript.isEmpty { parts.append(transcript) }
      for output in store.outputs(for: note) where
        !output.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parts.append("## \(output.actionTitle)\n\(output.content)")
      }
      return parts.joined(separator: "\n\n")
    }
    .joined(separator: "\n\n---\n\n")
  }

  private func exportSelection() {
    let notes = selectedNotes
    guard !notes.isEmpty else { return }
    var items: [Any] = [combinedText(for: notes)]
    if let directory = try? AudioFileStore.directoryURL() {
      for note in notes where !note.audioFileName.isEmpty {
        let url = directory.appending(path: note.audioFileName)
        if FileManager.default.fileExists(atPath: url.path()) {
          items.append(url)
        }
      }
    }
    shareItems = items
  }

  private func emailSelection() {
    let notes = selectedNotes
    guard !notes.isEmpty else { return }
    guard MailComposerView.canSendMail else {
      store.errorMessage = "Mail isn't set up on this device."
      return
    }
    let recipient = store.defaultEmailRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefix = store.emailSubjectPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
    let subject = prefix.isEmpty
      ? "\(notes.count) Voxora memos"
      : "\(prefix) — \(notes.count) memos"
    batchEmailDraft = EmailDraft(
      recipients: recipient.isEmpty ? [] : [recipient],
      subject: subject,
      body: combinedText(for: notes)
    )
  }
}

private struct ActivityView: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct RecordingMeterView: View {
  let samples: [CGFloat]
  let color: Color

  var body: some View {
    HStack(alignment: .center, spacing: 1.5) {
      ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
          .fill(color)
          .frame(width: 2.5)
          .frame(height: max(2, sample * 54))
      }
    }
    .animation(.easeOut(duration: 0.1), value: samples)
    .accessibilityHidden(true)
  }
}
