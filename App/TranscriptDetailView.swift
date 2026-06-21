import SwiftUI

struct TranscriptDetailView: View {
  @Bindable var store: VoxoraStore
  @Bindable var note: AudioNote

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
        Text("3-Prompt Manager")
          .font(.headline)

        Button {
          Task {
            await store.transform(note, kind: .todo)
          }
        } label: {
          actionLabel(title: "To-Do Transformer", systemImage: "checklist")
        }
        .buttonStyle(.glassProminent)

        Button {
          Task {
            await store.transform(note, kind: .bullets)
          }
        } label: {
          actionLabel(title: "Numbered/Bulleted List", systemImage: "list.bullet.rectangle.portrait")
        }
        .buttonStyle(.glassProminent)

        Button {
          Task {
            await store.transform(note, kind: .custom)
          }
        } label: {
          actionLabel(title: "Custom Action", systemImage: "wand.and.stars")
        }
        .buttonStyle(.glass)
      }
      .padding(20)
      .glassEffect(.regular.tint(.blue).interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private var outputBlock: some View {
    GlassEffectContainer(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Label("Transformed Output", systemImage: "sparkles")
          .font(.headline)
        Text(note.transformedOutputText.isEmpty ? "Run one of the prompts above to generate the polished output." : note.transformedOutputText)
          .frame(maxWidth: .infinity, alignment: .leading)
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
}
