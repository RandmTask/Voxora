import SwiftUI

struct AudioNoteCard: View {
  var note: AudioNote

  var body: some View {
    GlassEffectContainer(spacing: 14) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(note.tag ?? "Voice note")
              .font(.headline)
            Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Text(note.processingStatus.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: .capsule)
        }

        Text(note.transcriptText.isEmpty ? "Waiting for transcription…" : note.transcriptText)
          .font(.subheadline)
          .lineLimit(3)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
    }
  }
}
