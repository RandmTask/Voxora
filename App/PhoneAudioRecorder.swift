import AVFoundation
import Observation

struct PhoneRecording {
  let noteID: UUID
  let createdAt: Date
  let duration: TimeInterval
  let fileURL: URL
}

@MainActor
@Observable
final class PhoneAudioRecorder: NSObject, AVAudioRecorderDelegate {
  var state: RecordingState = .idle
  var elapsedTime: TimeInterval = 0
  var errorMessage: String?

  private var recorder: AVAudioRecorder?
  private var noteID = UUID()
  private var createdAt = Date.now
  private var timer: Timer?

  func start() async throws {
    let allowed = await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
    }
    guard allowed else {
      throw NSError(
        domain: "Voxora",
        code: 20,
        userInfo: [NSLocalizedDescriptionKey: "Microphone permission was denied."]
      )
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
    try session.setActive(true)

    noteID = UUID()
    createdAt = .now
    elapsedTime = 0
    let url = try AudioFileStore.destinationURL(noteID: noteID)
    recorder = try AVAudioRecorder(
      url: url,
      settings: [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]
    )
    recorder?.delegate = self
    recorder?.prepareToRecord()
    recorder?.record()
    state = .recording
    startTimer()
  }

  func pause() {
    guard state == .recording else { return }
    recorder?.pause()
    state = .paused
    stopTimer()
  }

  func resume() {
    guard state == .paused else { return }
    recorder?.record()
    state = .recording
    startTimer()
  }

  func finish() throws -> PhoneRecording {
    guard let recorder, state != .idle else {
      throw NSError(
        domain: "Voxora",
        code: 21,
        userInfo: [NSLocalizedDescriptionKey: "There is no active recording."]
      )
    }
    let duration = max(recorder.currentTime, elapsedTime)
    let fileURL = recorder.url
    recorder.stop()
    stopTimer()
    let result = PhoneRecording(
      noteID: noteID,
      createdAt: createdAt,
      duration: duration,
      fileURL: fileURL
    )
    self.recorder = nil
    state = .idle
    elapsedTime = 0
    try? AVAudioSession.sharedInstance().setActive(false)
    return result
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.elapsedTime = self?.recorder?.currentTime ?? 0 }
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
    elapsedTime = recorder?.currentTime ?? elapsedTime
  }
}
