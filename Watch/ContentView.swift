import SwiftUI

struct ContentView: View {
  @Bindable var audioEngineManager: WatchAudioEngineManager
  @Bindable var connectivityCoordinator: WatchConnectivityCoordinator

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      LinearGradient(
        colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.12, green: 0.11, blue: 0.2)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 8) {
        Spacer(minLength: 2)
        Button(action: primaryAction) {
          ZStack {
            Circle()
              .stroke(ringColor.opacity(0.25), lineWidth: 10)
            Circle()
              .trim(from: 0, to: 0.96)
              .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 4]))
              .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
              Image(systemName: primaryIcon)
                .font(.title2.weight(.bold))
              Text(primaryTitle)
                .font(.headline.weight(.heavy))
              Text(primarySubtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
              if audioEngineManager.stateIsActive {
                Text(formattedDuration(audioEngineManager.elapsedTime))
                  .font(.caption.monospacedDigit().weight(.semibold))
              }
            }
          }
          .frame(width: 150, height: 150)
          .contentShape(Circle())
        }
        .buttonStyle(.plain)

        Text(connectivityCoordinator.lastTransferDescription)
          .font(.system(size: 9))
          .lineLimit(1)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      if audioEngineManager.stateIsActive {
        Button {
          finishAndTransfer()
        } label: {
          Image(systemName: "stop.fill")
            .font(.caption.weight(.bold))
            .frame(width: 34, height: 34)
            .background(.red, in: Circle())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(8)
      }
    }
    .task(id: audioEngineManager.pausedAt) {
      guard let pausedAt = audioEngineManager.pausedAt else { return }
      let remaining = max(0, 600 - Date().timeIntervalSince(pausedAt))
      try? await Task.sleep(for: .seconds(remaining))
      guard !Task.isCancelled, audioEngineManager.recordingState == .paused else { return }
      finishAndTransfer()
    }
    .alert("Voxora", isPresented: Binding(
      get: { audioEngineManager.errorMessage != nil },
      set: { if !$0 { audioEngineManager.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(audioEngineManager.errorMessage ?? "")
    }
  }

  private var ringColor: Color {
    switch audioEngineManager.recordingState {
    case .recording: .red
    case .paused: .orange
    case .finalizing: .blue
    case .idle: .cyan
    }
  }

  private var primaryTitle: String {
    switch audioEngineManager.recordingState {
    case .idle: "START"
    case .recording: connectivityCoordinator.primaryButtonBehavior == .pause ? "PAUSE" : "SAVE"
    case .paused: "RESUME"
    case .finalizing: "SAVING"
    }
  }

  private var primarySubtitle: String {
    switch audioEngineManager.recordingState {
    case .idle: "Tap to record"
    case .recording: connectivityCoordinator.primaryButtonBehavior == .pause ? "Tap to pause" : "Tap to finish"
    case .paused: "Ends after 10 min"
    case .finalizing: "Sending to iPhone"
    }
  }

  private var primaryIcon: String {
    switch audioEngineManager.recordingState {
    case .idle: "mic.fill"
    case .recording: connectivityCoordinator.primaryButtonBehavior == .pause ? "pause.fill" : "checkmark"
    case .paused: "play.fill"
    case .finalizing: "arrow.up.circle.fill"
    }
  }

  private func primaryAction() {
    switch audioEngineManager.recordingState {
    case .idle, .paused:
      Task {
        do { try await audioEngineManager.startOrResumeRecording() }
        catch { audioEngineManager.errorMessage = error.localizedDescription }
      }
    case .recording:
      if connectivityCoordinator.primaryButtonBehavior == .pause {
        audioEngineManager.pauseRecording()
      } else {
        finishAndTransfer()
      }
    case .finalizing:
      break
    }
  }

  private func finishAndTransfer() {
    Task {
      do {
        let recording = try await audioEngineManager.finishRecording()
        connectivityCoordinator.transfer(recording: recording)
      } catch {
        audioEngineManager.errorMessage = error.localizedDescription
      }
    }
  }

  private func formattedDuration(_ duration: TimeInterval) -> String {
    String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60)
  }
}

private extension WatchAudioEngineManager {
  var stateIsActive: Bool {
    recordingState == .recording || recordingState == .paused || recordingState == .finalizing
  }
}
