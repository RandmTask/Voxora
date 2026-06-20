import SwiftUI

struct VoiceSynapseHomeView: View {
  @Bindable var store: VoiceSynapseStore
  @State private var isShowingSettings = false
  @State private var isPresentingMail = false

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [
            Color(red: 0.08, green: 0.11, blue: 0.2),
            Color(red: 0.16, green: 0.36, blue: 0.62),
            Color(red: 0.72, green: 0.87, blue: 0.96)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            hero

            ForEach(store.notes) { note in
              NavigationLink {
                TranscriptDetailView(store: store, note: note)
              } label: {
                AudioNoteCard(note: note)
              }
              .buttonStyle(.plain)
              .contextMenu {
                Button("Retry Transcription", systemImage: "arrow.clockwise") {
                  Task {
                    await store.retry(note)
                  }
                }
                Button("Apply To-Do Prompt", systemImage: "checklist") {
                  Task {
                    await store.transform(note, kind: .todo)
                  }
                }
                Button("Apply List Prompt", systemImage: "list.bullet.rectangle") {
                  Task {
                    await store.transform(note, kind: .bullets)
                  }
                }
                Divider()
                Button(note.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar") {}
                  .disabled(true)
                Button(note.processingStatus.title, systemImage: "bolt.horizontal.circle") {}
                  .disabled(true)
              }
              .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button("Email", systemImage: "envelope") {
                  store.queueEmail(for: note)
                  isPresentingMail = store.pendingEmailDraft != nil
                }
                .tint(.blue)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Archive", systemImage: "archivebox") {
                  store.archive(note)
                }
                .tint(.orange)

                Button("Delete", systemImage: "trash") {
                  store.delete(note)
                }
                .tint(.red)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(20)
        }
      }
      .navigationTitle("VoiceSynapse")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Settings", systemImage: "gearshape") {
            isShowingSettings = true
          }
          .labelStyle(.iconOnly)
        }
      }
      .sheet(isPresented: $isShowingSettings) {
        SettingsView(store: store)
      }
      .sheet(isPresented: $isPresentingMail, onDismiss: store.dismissEmailDraft) {
        if let draft = store.pendingEmailDraft {
          MailComposerView(draft: draft, isPresented: $isPresentingMail)
        }
      }
      .alert("VoiceSynapse", isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { isPresented in
          if !isPresented {
            store.errorMessage = nil
          }
        }
      )) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(store.errorMessage ?? "")
      }
    }
  }

  private var hero: some View {
    GlassEffectContainer(spacing: 18) {
      VStack(alignment: .leading, spacing: 14) {
        Text("Dual-device capture and AI transform")
          .font(.system(size: 30, weight: .bold, design: .rounded))
        Text("Watch records in pause/resume chunks, the iPhone transcribes, then three prompts reshape the result.")
          .font(.headline)
          .foregroundStyle(.secondary)

        HStack(spacing: 12) {
          StatusPill(title: "\(store.notes.count) Notes", systemImage: "waveform.badge.mic")
          StatusPill(title: "\(store.prompts.count) Prompts", systemImage: "sparkles.rectangle.stack")
          StatusPill(title: store.isProcessing ? "Processing" : "Ready", systemImage: "bolt.horizontal.circle")
        }
      }
      .padding(22)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassEffect(.regular.tint(.blue).interactive(), in: .rect(cornerRadius: 30))
    }
  }
}
