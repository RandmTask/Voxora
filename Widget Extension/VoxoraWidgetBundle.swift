import SwiftUI
import WidgetKit

@main
struct VoxoraWidgetBundle: WidgetBundle {
  var body: some Widget {
    VoxoraComplicationWidget()
  }
}

struct VoxoraComplicationWidget: Widget {
  private let kind = "com.swiftstudio.Voxora.watchkitapp.widget-extension.record"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VoxoraTimelineProvider()) { entry in
      VoxoraComplicationEntryView(entry: entry)
        .widgetURL(URL(string: "voxora://record"))
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

struct VoxoraTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> VoxoraEntry {
    VoxoraEntry(date: .now, snapshot: .current())
  }

  func getSnapshot(in context: Context, completion: @escaping (VoxoraEntry) -> Void) {
    completion(VoxoraEntry(date: .now, snapshot: .current()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VoxoraEntry>) -> Void) {
    let currentDate = Date()
    let entries = stride(from: 0, to: 5, by: 1).map { offset in
      VoxoraEntry(
        date: Calendar.current.date(byAdding: .minute, value: offset * 15, to: currentDate) ?? currentDate,
        snapshot: .current()
      )
    }
    completion(Timeline(entries: entries, policy: .after(currentDate.addingTimeInterval(15 * 60))))
  }
}

struct VoxoraEntry: TimelineEntry {
  var date: Date
  var snapshot: WatchRecordingSnapshot
}

struct VoxoraComplicationEntryView: View {
  var entry: VoxoraEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryCorner:
      Image("VoxoraComplication")
        .resizable()
        .scaledToFit()
        .padding(3)
        .foregroundStyle(entry.snapshot.state == .recording ? .red : .blue)
    case .accessoryCircular:
      ZStack {
        Circle()
          .fill(.black.opacity(0.15))
        Image("VoxoraComplication")
          .resizable()
          .scaledToFit()
          .padding(7)
          .foregroundStyle(entry.snapshot.state == .recording ? .red : .blue)
      }
    case .accessoryInline:
      Text(inlineTitle)
    case .accessoryRectangular:
      HStack(spacing: 6) {
        Image("VoxoraComplication")
          .resizable()
          .scaledToFit()
          .frame(width: 24, height: 24)
          .foregroundStyle(entry.snapshot.state == .recording ? .red : .blue)
        VStack(alignment: .leading, spacing: 2) {
          Text("Voxora")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text(rectangularTitle)
            .font(.headline)
        }
      }
    default:
      Text(entry.date, style: .time)
    }
  }

  private var inlineTitle: String {
    switch entry.snapshot.state {
    case .recording:
      "Voxora Recording"
    case .paused:
      "Voxora Paused"
    case .finalizing:
      "Voxora Stitching"
    case .idle:
      "Voxora Ready"
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
