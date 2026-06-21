import SwiftUI

struct AudioNoteCard: View {
  var note: AudioNote
  var isPlaying = false

  var body: some View {
    GlassEffectContainer(spacing: 14) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              HStack(spacing: 6) {
                if note.isFavorite {
                  Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                }
                Text(note.displayTitle)
                  .font(.headline)
              }
              Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isPlaying || (note.processingStatus != .ready && note.processingStatus != .idle) {
              Label(
                isPlaying ? "Playing" : note.processingStatus.title,
                systemImage: isPlaying ? "speaker.wave.2.fill" : statusIcon
              )
              .font(.caption.weight(.semibold))
              .foregroundStyle(statusColor)
            }
          }

          Text(previewText)
            .font(.subheadline)
            .lineLimit(3)

          if note.archivedAt != nil {
            Label("Archived", systemImage: "archivebox")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          HStack {
            Text(formattedDuration)
            if !note.audioFileName.isEmpty {
              Text("•")
              Text("Long-press for actions")
            }
          }
          .font(.caption2)
          .foregroundStyle(.tertiary)
        }

        VStack(spacing: 0) {
          if !isPlaying && note.processingStatus == .ready {
            Image(systemName: "checkmark.circle")
              .font(.title3.weight(.semibold))
              .foregroundStyle(.green)
              .accessibilityLabel("Ready")
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.body.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .frame(width: 22)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
    }
  }

  private var previewText: String {
    switch note.processingStatus {
    case .tooShort: "This recording was shorter than one second."
    case .empty: "No speech was detected in this recording."
    case .failed: "Transcription failed. Swipe right to try again."
    default: note.transcriptText.isEmpty ? "Waiting for transcription…" : note.transcriptText
    }
  }

  private var statusIcon: String {
    switch note.processingStatus {
    case .tooShort: "timer"
    case .empty: "waveform.slash"
    case .failed: "exclamationmark.triangle"
    case .transcribing, .uploading: "ellipsis.circle"
    case .ready: "checkmark.circle"
    case .idle: "circle"
    }
  }

  private var statusColor: Color {
    switch note.processingStatus {
    case .tooShort, .empty: .orange
    case .failed: .red
    case .ready: .green
    default: .secondary
    }
  }

  private var formattedDuration: String {
    let seconds = Int(note.duration.rounded())
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
