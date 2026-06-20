import SwiftUI
import WidgetKit

@main
struct VoiceSynapseWidgetBundle: WidgetBundle {
  var body: some Widget {
    VoiceSynapseComplicationWidget()
  }
}

struct VoiceSynapseComplicationWidget: Widget {
  private let kind = "app.bitrig.new.bfc9a3b4-4284-492c-86c4-550c634ba81e.watchkitapp.widget-extension.record"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VoiceSynapseTimelineProvider()) { entry in
      VoiceSynapseComplicationEntryView(entry: entry)
        .widgetURL(URL(string: "voicesynapse://record"))
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Quick Record")
    .description("Jump straight into a recording session.")
    .supportedFamilies([
      .accessoryCircular,
      .accessoryCorner,
      .accessoryInline,
      .accessoryRectangular
    ])
  }
}

struct VoiceSynapseTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> VoiceSynapseEntry {
    VoiceSynapseEntry(date: .now, snapshot: .current())
  }

  func getSnapshot(in context: Context, completion: @escaping (VoiceSynapseEntry) -> Void) {
    completion(VoiceSynapseEntry(date: .now, snapshot: .current()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceSynapseEntry>) -> Void) {
    let currentDate = Date()
    let entries = stride(from: 0, to: 5, by: 1).map { offset in
      VoiceSynapseEntry(
        date: Calendar.current.date(byAdding: .minute, value: offset * 15, to: currentDate) ?? currentDate,
        snapshot: .current()
      )
    }
    completion(Timeline(entries: entries, policy: .after(currentDate.addingTimeInterval(15 * 60))))
  }
}

struct VoiceSynapseEntry: TimelineEntry {
  var date: Date
  var snapshot: WatchRecordingSnapshot
}

struct VoiceSynapseComplicationEntryView: View {
  var entry: VoiceSynapseEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryCorner:
      Text(entry.snapshot.state == .recording ? "REC" : "GO")
        .font(.system(.headline, design: .rounded, weight: .bold))
        .foregroundStyle(entry.snapshot.state == .recording ? .red : .blue)
    case .accessoryCircular:
      ZStack {
        Circle()
          .fill(.black.opacity(0.15))
        Image(systemName: entry.snapshot.state == .recording ? "waveform.circle.fill" : "record.circle")
          .font(.title3)
          .foregroundStyle(entry.snapshot.state == .recording ? .red : .blue)
      }
    case .accessoryInline:
      Text(inlineTitle)
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Text("VoiceSynapse")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(rectangularTitle)
          .font(.headline)
      }
    default:
      Text(entry.date, style: .time)
    }
  }

  private var inlineTitle: String {
    switch entry.snapshot.state {
    case .recording:
      "VoiceSynapse Recording"
    case .paused:
      "VoiceSynapse Paused"
    case .finalizing:
      "VoiceSynapse Stitching"
    case .idle:
      "VoiceSynapse Ready"
    }
  }

  private var rectangularTitle: String {
    switch entry.snapshot.state {
    case .recording:
      "Recording · \(entry.snapshot.chunkCount) chunks"
    case .paused:
      "Paused · resume session"
    case .finalizing:
      "Finalizing audio"
    case .idle:
      "Tap to record"
    }
  }
}
