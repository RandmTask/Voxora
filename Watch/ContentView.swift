import SwiftUI

struct ContentView: View {
  @Bindable var audioEngineManager: WatchAudioEngineManager
  @Bindable var connectivityCoordinator: WatchConnectivityCoordinator

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          timerCard
          controls
          transferStatus
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
      }
      .navigationTitle("VoiceSynapse")
      .alert("Watch Recorder", isPresented: Binding(
        get: { audioEngineManager.errorMessage != nil },
        set: { value in
          if !value {
            audioEngineManager.errorMessage = nil
          }
        }
      )) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(audioEngineManager.errorMessage ?? "")
      }
    }
  }

  private var timerCard: some View {
    VStack(spacing: 10) {
      Text(formattedDuration(audioEngineManager.elapsedTime))
        .font(.system(size: 34, weight: .bold, design: .rounded))
      Text("\(audioEngineManager.chunkCount) chunks")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(audioEngineManager.recordingState.rawValue.capitalized)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.blue)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
  }

  private var controls: some View {
    HStack(spacing: 10) {
      Button(
        audioEngineManager.recordingState == .recording ? "Pause" : "Resume",
        systemImage: audioEngineManager.recordingState == .recording ? "pause.fill" : "record.circle.fill"
      ) {
        Task {
          do {
            if audioEngineManager.recordingState == .recording {
              audioEngineManager.pauseRecording()
            } else {
              try await audioEngineManager.startOrResumeRecording()
            }
          } catch {
            audioEngineManager.errorMessage = error.localizedDescription
          }
        }
      }
      .buttonStyle(.bordered)

      Button("End", systemImage: "stop.fill") {
        Task {
          do {
            let recording = try await audioEngineManager.finishRecording()
            connectivityCoordinator.transfer(recording: recording)
          } catch {
            audioEngineManager.errorMessage = error.localizedDescription
          }
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(.blue)
      .disabled(audioEngineManager.recordingState == .idle || audioEngineManager.recordingState == .finalizing)
    }
  }

  private var transferStatus: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Handoff")
        .font(.headline)
      Text(connectivityCoordinator.lastTransferDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private func formattedDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = Int(duration)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }
}
