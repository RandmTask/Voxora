import SwiftUI

struct AudioNoteCard: View {
  var note: AudioNote
  var isPlaying = false

  var body: some View {
    GlassEffectContainer(spacing: 14) {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              if note.isFavorite {
                Image(systemName: "star.fill")
                  .foregroundStyle(.yellow)
              }
              Text(note.displayTitle)
                .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusView
              .fixedSize()
          }

          Text("\(note.timestamp.formatted(date: .abbreviated, time: .shortened)) (\(formattedDuration))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.trailing, 30)

        Text(previewText)
          .font(.subheadline)
          .lineLimit(3)

        if note.archivedAt != nil {
          Label("Archived", systemImage: "archivebox")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(18)
      .padding(.trailing, 28)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
      .overlay(alignment: .trailing) {
        Image(systemName: "chevron.right")
          .font(.body.weight(.semibold))
          .foregroundStyle(.tertiary)
          .padding(.trailing, 18)
      }
    }
  }

  @ViewBuilder
  private var statusView: some View {
    if isPlaying {
      statusLabel("Playing", systemImage: "speaker.wave.2.fill")
    } else if note.displayedProcessingStatus == .ready {
      Image(systemName: "checkmark.circle")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.green)
        .accessibilityLabel("Ready")
    } else if note.displayedProcessingStatus != .idle {
      statusLabel(note.displayedProcessingStatus.title, systemImage: statusIcon)
    }
  }

  private func statusLabel(_ title: String, systemImage: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 5) {
      Text(title)
      Image(systemName: systemImage)
        .font(.title3.weight(.semibold))
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(statusColor)
  }

  private var previewText: String {
    switch note.displayedProcessingStatus {
    case .tooShort: "This recording was three seconds or shorter."
    case .empty: "No speech was detected in this recording."
    case .failed: "Transcription failed. Swipe right to try again."
    default: note.transcriptText.isEmpty ? "Waiting for transcription…" : note.transcriptText
    }
  }

  private var statusIcon: String {
    switch note.displayedProcessingStatus {
    case .tooShort: "timer"
    case .empty: "waveform.slash"
    case .failed: "exclamationmark.triangle"
    case .transcribing, .uploading: "ellipsis.circle"
    case .ready: "checkmark.circle"
    case .idle: "circle"
    }
  }

  private var statusColor: Color {
    switch note.displayedProcessingStatus {
    case .tooShort, .empty: .orange
    case .failed: .red
    case .ready: .green
    default: .secondary
    }
  }

  private var formattedDuration: String {
    let seconds = max(0, Int(note.duration.rounded()))
    let minutes = seconds / 60
    let remainder = seconds % 60
    return minutes == 0 ? "\(remainder)s" : "\(minutes)m\(remainder)s"
  }
}
