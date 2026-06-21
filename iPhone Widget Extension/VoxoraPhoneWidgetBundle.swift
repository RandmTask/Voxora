import SwiftUI
import WidgetKit

@main
struct VoxoraPhoneWidgetBundle: WidgetBundle {
  var body: some Widget {
    VoxoraQuickRecordWidget()
    VoxoraOpenAppWidget()
  }
}

private struct VoxoraPhoneEntry: TimelineEntry {
  let date: Date
}

private struct VoxoraPhoneTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> VoxoraPhoneEntry {
    VoxoraPhoneEntry(date: .now)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (VoxoraPhoneEntry) -> Void
  ) {
    completion(VoxoraPhoneEntry(date: .now))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<VoxoraPhoneEntry>) -> Void
  ) {
    completion(Timeline(entries: [VoxoraPhoneEntry(date: .now)], policy: .never))
  }
}

private struct VoxoraQuickRecordWidget: Widget {
  private let kind = "com.swiftstudio.Voxora.widget.quick-record"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VoxoraPhoneTimelineProvider()) { _ in
      VoxoraQuickRecordView()
        .widgetURL(URL(string: "voxora://record"))
        .containerBackground(for: .widget) {
          LinearGradient(
            colors: [
              Color(red: 0.04, green: 0.11, blue: 0.17),
              Color(red: 0.04, green: 0.25, blue: 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
    }
    .configurationDisplayName("Quick Record")
    .description("Open Voxora and immediately start an iPhone recording.")
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .accessoryCircular,
      .accessoryInline,
      .accessoryRectangular
    ])
  }
}

private struct VoxoraQuickRecordView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .systemSmall:
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "mic.fill")
          .font(.system(size: 32, weight: .semibold))
          .foregroundStyle(.cyan)
        Spacer()
        Text("Quick Record")
          .font(.headline)
        Text("Tap to start")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .systemMedium:
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: "waveform")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.cyan)
          Text("Capture a thought")
            .font(.headline)
          Text("Start recording immediately or open your recent notes.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        VStack(spacing: 10) {
          Link(destination: URL(string: "voxora://record")!) {
            Label("Record", systemImage: "mic.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)

          Link(destination: URL(string: "voxora://open")!) {
            Label("Open App", systemImage: "arrow.up.forward.app")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
        .frame(width: 116)
      }
    case .accessoryCircular:
      Image(systemName: "mic.fill")
        .font(.title2)
        .widgetAccentable()
    case .accessoryInline:
      Label("Quick Record", systemImage: "mic.fill")
    case .accessoryRectangular:
      HStack {
        Image(systemName: "mic.fill")
          .font(.title2)
          .widgetAccentable()
        VStack(alignment: .leading) {
          Text("Quick Record")
            .font(.headline)
          Text("Tap to start")
            .font(.caption)
        }
      }
    default:
      EmptyView()
    }
  }
}

private struct VoxoraOpenAppWidget: Widget {
  private let kind = "com.swiftstudio.Voxora.widget.open"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VoxoraPhoneTimelineProvider()) { _ in
      VoxoraOpenAppView()
        .widgetURL(URL(string: "voxora://open"))
        .containerBackground(for: .widget) {
          LinearGradient(
            colors: [
              Color(red: 0.08, green: 0.07, blue: 0.16),
              Color(red: 0.16, green: 0.1, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
    }
    .configurationDisplayName("Open Voxora")
    .description("Open Voxora without starting a recording.")
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .accessoryCircular,
      .accessoryInline,
      .accessoryRectangular
    ])
  }
}

private struct VoxoraOpenAppView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .systemSmall:
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "waveform")
          .font(.system(size: 32, weight: .semibold))
          .foregroundStyle(.purple)
        Spacer()
        Text("Voxora")
          .font(.headline)
        Text("Open voice notes")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .systemMedium:
      HStack(spacing: 16) {
        Image(systemName: "waveform")
          .font(.system(size: 42, weight: .semibold))
          .foregroundStyle(.purple)
        VStack(alignment: .leading, spacing: 6) {
          Text("Open Voxora")
            .font(.title3.weight(.bold))
          Text("Review recordings, transcripts, summaries, and AI outputs.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
    case .accessoryCircular:
      Image(systemName: "waveform")
        .font(.title2)
        .widgetAccentable()
    case .accessoryInline:
      Label("Open Voxora", systemImage: "waveform")
    case .accessoryRectangular:
      HStack {
        Image(systemName: "waveform")
          .font(.title2)
          .widgetAccentable()
        VStack(alignment: .leading) {
          Text("Voxora")
            .font(.headline)
          Text("Open voice notes")
            .font(.caption)
        }
      }
    default:
      EmptyView()
    }
  }
}
