import AVFoundation
import Observation
import WidgetKit

@MainActor
@Observable
final class WatchAudioEngineManager {
  private static let recordingSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16_000,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false
  ]

  var recordingState: RecordingState = .idle
  var elapsedTime: TimeInterval = 0
  var chunkCount = 0
  var errorMessage: String?
  var pausedAt: Date?

  private var recorder: AVAudioRecorder?
  private var recorderStartDate: Date?
  private var sessionStartDate: Date?
  private var noteID = UUID()
  private var chunks: [RecordedChunk] = []
  private var timer: Timer?

  init() {
    restorePersistedSession()
  }

  func startOrResumeRecording() async throws {
    guard recordingState != .recording && recordingState != .finalizing else {
      return
    }

    try await configureAudioSession()

    if recordingState == .idle {
      noteID = UUID()
      sessionStartDate = .now
      chunks = []
      elapsedTime = 0
    }

    let outputURL = try AudioFileStore.directoryURL()
      .appending(path: "\(noteID.uuidString)-chunk-\(chunks.count + 1)-\(UUID().uuidString).caf")

    recorder = try AVAudioRecorder(url: outputURL, settings: Self.recordingSettings)
    recorder?.prepareToRecord()
    recorder?.record()
    recorderStartDate = .now
    recordingState = .recording
    pausedAt = nil
    startTimer()
    persistSnapshot()
  }

  func pauseRecording() {
    guard recordingState == .recording, let recorder else {
      return
    }

    let duration = recorder.currentTime
    recorder.stop()
    chunks.append(RecordedChunk(url: recorder.url, duration: duration))
    self.recorder = nil
    recorderStartDate = nil
    recordingState = .paused
    pausedAt = .now
    chunkCount = chunks.count
    stopTimer()
    persistSnapshot()
  }

  func finishRecording() async throws -> FinalizedRecording {
    if recordingState == .recording {
      pauseRecording()
    }

    guard !chunks.isEmpty, let recordingStartedAt = sessionStartDate else {
      throw NSError(domain: "Voxora", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio chunks were captured."])
    }

    recordingState = .finalizing
    persistSnapshot()

    let outputURL = try AudioFileStore.destinationURL(noteID: noteID, fileExtension: "caf")
    var totalDuration: TimeInterval = 0

    if FileManager.default.fileExists(atPath: outputURL.path()) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let firstChunk = try AVAudioFile(forReading: chunks[0].url)
    let destinationFile = try AVAudioFile(
      forWriting: outputURL,
      settings: firstChunk.fileFormat.settings
    )

    for chunk in chunks {
      let sourceFile = try AVAudioFile(forReading: chunk.url)
      totalDuration += Double(sourceFile.length) / sourceFile.processingFormat.sampleRate
      try append(sourceFile: sourceFile, to: destinationFile)
    }

    cleanupChunks()
    stopTimer()
    recordingState = .idle
    pausedAt = nil
    elapsedTime = 0
    chunkCount = 0
    sessionStartDate = nil
    persistSnapshot()

    return FinalizedRecording(
      noteID: noteID,
      createdAt: recordingStartedAt,
      duration: totalDuration,
      tag: "Watch Capture",
      fileURL: outputURL
    )
  }

  private func configureAudioSession() async throws {
    let session = AVAudioSession.sharedInstance()
    let granted = await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { allowed in
        continuation.resume(returning: allowed)
      }
    }

    guard granted else {
      throw NSError(domain: "Voxora", code: 4, userInfo: [NSLocalizedDescriptionKey: "Microphone permission was denied."])
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
    defaults?.set(
      recordingState == .idle ? nil : noteID.uuidString,
      forKey: AppPreferences.recordingNoteIDKey
    )
    WidgetCenter.shared.reloadAllTimelines()
  }

  private func restorePersistedSession() {
    let defaults = UserDefaults(suiteName: AppGroup.id)
    guard let noteIDString = defaults?.string(forKey: AppPreferences.recordingNoteIDKey),
          let restoredNoteID = UUID(uuidString: noteIDString) else {
      return
    }

    let rawState = defaults?.string(forKey: AppPreferences.recordingStateKey)
      ?? RecordingState.idle.rawValue
    let persistedState = RecordingState(rawValue: rawState) ?? .idle
    guard persistedState == .recording || persistedState == .paused else {
      return
    }

    do {
      let directory = try AudioFileStore.directoryURL()
      let prefix = "\(restoredNoteID.uuidString)-chunk-"
      let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )
      .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "caf" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

      noteID = restoredNoteID
      sessionStartDate = defaults?.object(
        forKey: AppPreferences.recordingStartDateKey
      ) as? Date
      chunks = try urls.map { url in
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        return RecordedChunk(url: url, duration: duration)
      }
      chunkCount = chunks.count
      elapsedTime = chunks.reduce(0) { $0 + $1.duration }
      recordingState = chunks.isEmpty ? .idle : .paused
      pausedAt = recordingState == .paused ? Date() : nil
      persistSnapshot()
    } catch {
      errorMessage = "The previous recording session could not be restored."
      recordingState = .idle
      persistSnapshot()
    }
  }

  private func append(sourceFile: AVAudioFile, to destinationFile: AVAudioFile) throws {
    let format = sourceFile.processingFormat
    let capacity = AVAudioFrameCount(max(1, min(sourceFile.length, 16_384)))

    while sourceFile.framePosition < sourceFile.length {
      let remainingFrames = sourceFile.length - sourceFile.framePosition
      let frameCount = AVAudioFrameCount(min(Int64(capacity), remainingFrames))
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw NSError(
          domain: "Voxora",
          code: 5,
          userInfo: [NSLocalizedDescriptionKey: "Unable to allocate an audio merge buffer."]
        )
      }
      try sourceFile.read(into: buffer, frameCount: frameCount)
      guard buffer.frameLength > 0 else { break }
      destinationFile.framePosition = destinationFile.length
      try destinationFile.write(from: buffer)
    }
  }

}
