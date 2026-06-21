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

private enum VoxoraWidgetStyle {
  static let accent = Color(red: 0.08, green: 0.78, blue: 0.92)
  static let primaryText = Color.white
  static let secondaryText = Color.white.opacity(0.68)
  static let actionFill = Color.white.opacity(0.12)
  static let actionStroke = Color.white.opacity(0.2)
  static let background = LinearGradient(
    colors: [
      Color(red: 0.045, green: 0.075, blue: 0.13),
      Color(red: 0.035, green: 0.2, blue: 0.25)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

private struct VoxoraQuickRecordWidget: Widget {
  private let kind = "com.swiftstudio.Voxora.widget.quick-record"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VoxoraPhoneTimelineProvider()) { _ in
      VoxoraQuickRecordView()
        .widgetURL(URL(string: "voxora://record"))
        .containerBackground(for: .widget) {
          VoxoraWidgetStyle.background
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
        Image(systemName: "waveform")
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(VoxoraWidgetStyle.accent)
        Spacer()
        Text("Quick Record")
          .font(.headline)
          .foregroundStyle(VoxoraWidgetStyle.primaryText)
        Text("Tap to start")
          .font(.caption)
          .foregroundStyle(VoxoraWidgetStyle.secondaryText)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .systemMedium:
      HStack(spacing: 18) {
        VStack(alignment: .leading, spacing: 7) {
          Image(systemName: "waveform")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(VoxoraWidgetStyle.accent)
          Text("Capture a thought")
            .font(.headline)
            .foregroundStyle(VoxoraWidgetStyle.primaryText)
          Text("Record now or open your notes.")
            .font(.caption)
            .foregroundStyle(VoxoraWidgetStyle.secondaryText)
        }

        Spacer(minLength: 0)

        VStack(spacing: 8) {
          Link(destination: URL(string: "voxora://record")!) {
            VoxoraWidgetActionLabel(title: "Record", systemImage: "mic.fill", isPrimary: true)
          }

          Link(destination: URL(string: "voxora://open")!) {
            VoxoraWidgetActionLabel(title: "Open", systemImage: "arrow.up.forward.app")
          }
        }
        .frame(width: 108)
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
          VoxoraWidgetStyle.background
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
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(VoxoraWidgetStyle.accent)
        Spacer()
        Text("Open Voxora")
          .font(.headline)
          .foregroundStyle(VoxoraWidgetStyle.primaryText)
        Text("View your notes")
          .font(.caption)
          .foregroundStyle(VoxoraWidgetStyle.secondaryText)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .systemMedium:
      HStack(spacing: 18) {
        VStack(alignment: .leading, spacing: 7) {
          Image(systemName: "waveform")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(VoxoraWidgetStyle.accent)
          Text("Open Voxora")
            .font(.headline)
            .foregroundStyle(VoxoraWidgetStyle.primaryText)
          Text("Review recordings and transcripts.")
            .font(.caption)
            .foregroundStyle(VoxoraWidgetStyle.secondaryText)
        }

        Spacer(minLength: 0)

        VoxoraWidgetActionLabel(title: "Open", systemImage: "arrow.up.forward.app", isPrimary: true)
          .frame(width: 108)
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

private struct VoxoraWidgetActionLabel: View {
  let title: String
  let systemImage: String
  var isPrimary = false

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .foregroundStyle(isPrimary ? Color(red: 0.02, green: 0.12, blue: 0.16) : .white)
      .frame(maxWidth: .infinity)
      .frame(height: 38)
      .background(
        isPrimary ? VoxoraWidgetStyle.accent : VoxoraWidgetStyle.actionFill,
        in: Capsule()
      )
      .overlay {
        if !isPrimary {
          Capsule()
            .stroke(VoxoraWidgetStyle.actionStroke, lineWidth: 1)
        }
      }
  }
}
