import SwiftUI
import UIKit

struct TranscriptDetailView: View {
  @Bindable var store: VoxoraStore
  @Bindable var note: AudioNote
  @State private var isEditing = false
  @State private var isEmailing = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        transcriptBlock
        actionBlock
        outputBlock
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
    }
    .background(
      LinearGradient(
        colors: [
          Color(red: 0.04, green: 0.08, blue: 0.16),
          Color(red: 0.12, green: 0.28, blue: 0.43),
          Color(red: 0.84, green: 0.92, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
    .navigationTitle("Transcript")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit", systemImage: "pencil") {
            isEditing = true
          }

          Button("Copy", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = shareText
          }

          ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
          }

          Button("Email Memo", systemImage: "envelope") {
            isEmailing = true
          }
        } label: {
          Label("Note Actions", systemImage: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $isEditing) {
      NoteEditorSheet(store: store, note: note)
    }
    .sheet(isPresented: $isEmailing) {
      EmailWorkflowSheet(store: store, note: note)
    }
  }

  private var transcriptBlock: some View {
    GlassEffectContainer(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Label("Raw Transcript", systemImage: "text.quote")
          .font(.headline)
        Text(note.transcriptText.isEmpty ? "Transcription will appear here after watch handoff finishes." : note.transcriptText)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(20)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private var actionBlock: some View {
    GlassEffectContainer(spacing: 14) {
      VStack(alignment: .leading, spacing: 12) {
        Text("AI Actions")
          .font(.headline)

        ForEach(store.prompts.filter(\.isEnabled)) { action in
          Button {
            Task {
              await store.runAction(action, on: note)
            }
          } label: {
            actionLabel(title: action.title, systemImage: action.iconName)
          }
          .buttonStyle(.glassProminent)
        }
      }
      .padding(20)
      .glassEffect(.regular.tint(.blue).interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private var outputBlock: some View {
    GlassEffectContainer(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Label("Output History", systemImage: "sparkles")
          .font(.headline)
        if store.outputs(for: note).isEmpty {
          Text("Run an action above to generate an output.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(store.outputs(for: note)) { output in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(output.actionTitle)
                  .font(.subheadline.weight(.semibold))
                Spacer()
                Text(output.createdAt.formatted(date: .abbreviated, time: .shortened))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Text(output.content)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            if output.id != store.outputs(for: note).last?.id {
              Divider()
            }
          }
        }
      }
      .padding(20)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private func actionLabel(title: String, systemImage: String) -> some View {
    HStack {
      Label(title, systemImage: systemImage)
      Spacer()
      Image(systemName: "arrow.up.right")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity)
  }

  private var shareText: String {
    ([note.transcriptText] + store.outputs(for: note).map(\.content))
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: "\n\n")
  }
}
