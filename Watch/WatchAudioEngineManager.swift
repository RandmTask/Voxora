import AVFoundation
import Observation
import WidgetKit

@MainActor
@Observable
final class WatchAudioEngineManager {
  var recordingState: RecordingState = .idle
  var elapsedTime: TimeInterval = 0
  var chunkCount = 0
  var errorMessage: String?

  private var recorder: AVAudioRecorder?
  private var recorderStartDate: Date?
  private var sessionStartDate: Date?
  private var noteID = UUID()
  private var chunks: [RecordedChunk] = []
  private var timer: Timer?

  deinit {
    timer?.invalidate()
  }

  func startOrResumeRecording() async throws {
    try await configureAudioSession()

    if recordingState == .idle {
      noteID = UUID()
      sessionStartDate = .now
      chunks = []
      elapsedTime = 0
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appending(path: "\(noteID.uuidString)-chunk-\(chunks.count + 1).m4a")

    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    recorder = try AVAudioRecorder(url: outputURL, settings: settings)
    recorder?.prepareToRecord()
    recorder?.record()
    recorderStartDate = .now
    recordingState = .recording
    startTimer()
    persistSnapshot()
  }

  func pauseRecording() {
    guard recordingState == .recording, let recorder else {
      return
    }

    recorder.stop()
    let duration = recorder.currentTime
    chunks.append(RecordedChunk(url: recorder.url, duration: duration))
    self.recorder = nil
    recorderStartDate = nil
    recordingState = .paused
    chunkCount = chunks.count
    stopTimer()
    persistSnapshot()
  }

  func finishRecording() async throws -> FinalizedRecording {
    if recordingState == .recording {
      pauseRecording()
    }

    guard !chunks.isEmpty, let sessionStartDate else {
      throw NSError(domain: "VoiceSynapse", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio chunks were captured."])
    }

    recordingState = .finalizing
    persistSnapshot()

    let outputURL = try AudioFileStore.destinationURL(noteID: noteID)
    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      throw NSError(domain: "VoiceSynapse", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create composition track."])
    }

    var cursor = CMTime.zero
    var totalDuration: TimeInterval = 0
    for chunk in chunks {
      let asset = AVURLAsset(url: chunk.url)
      guard let sourceTrack = asset.tracks(withMediaType: .audio).first else {
        continue
      }
      let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
      try track.insertTimeRange(timeRange, of: sourceTrack, at: cursor)
      cursor = cursor + asset.duration
      totalDuration += chunk.duration
    }

    if FileManager.default.fileExists(atPath: outputURL.path()) {
      try FileManager.default.removeItem(at: outputURL)
    }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
      throw NSError(domain: "VoiceSynapse", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session."])
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a

    try await withCheckedThrowingContinuation { continuation in
      exportSession.exportAsynchronously {
        if let error = exportSession.error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }

    cleanupChunks()
    stopTimer()
    recordingState = .idle
    elapsedTime = 0
    chunkCount = 0
    persistSnapshot()

    return FinalizedRecording(
      noteID: noteID,
      createdAt: sessionStartDate,
      duration: totalDuration,
      tag: "Watch Capture",
      fileURL: outputURL
    )
  }

  private func configureAudioSession() async throws {
    let session = AVAudioSession.sharedInstance()
    let granted = await withCheckedContinuation { continuation in
      session.requestRecordPermission { allowed in
        continuation.resume(returning: allowed)
      }
    }

    guard granted else {
      throw NSError(domain: "VoiceSynapse", code: 4, userInfo: [NSLocalizedDescriptionKey: "Microphone permission was denied."])
    }

    try session.setCategory(.playAndRecord, mode: .default, options: [])
    try session.setActive(true)
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.updateElapsedTime()
      }
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
    updateElapsedTime()
  }

  private func updateElapsedTime() {
    let storedDuration = chunks.reduce(0) { $0 + $1.duration }
    let currentDuration: TimeInterval
    if recordingState == .recording, let recorderStartDate {
      currentDuration = Date().timeIntervalSince(recorderStartDate)
    } else {
      currentDuration = 0
    }
    elapsedTime = storedDuration + currentDuration
    chunkCount = chunks.count + (recordingState == .recording ? 1 : 0)
    persistSnapshot()
  }

  private func cleanupChunks() {
    for chunk in chunks {
      try? FileManager.default.removeItem(at: chunk.url)
    }
    chunks = []
  }

  private func persistSnapshot() {
    let defaults = UserDefaults(suiteName: AppGroup.id)
    defaults?.set(recordingState.rawValue, forKey: AppPreferences.recordingStateKey)
    defaults?.set(sessionStartDate, forKey: AppPreferences.recordingStartDateKey)
    defaults?.set(chunkCount, forKey: AppPreferences.recordingChunkCountKey)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
