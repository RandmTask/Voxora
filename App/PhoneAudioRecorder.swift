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
  var meterSamples = Array(repeating: CGFloat(0), count: 60)
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
    recorder?.isMeteringEnabled = true
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
    meterSamples = Array(repeating: 0, count: meterSamples.count)
    try? AVAudioSession.sharedInstance().setActive(false)
    return result
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self, let recorder = self.recorder else { return }
        self.elapsedTime = recorder.currentTime
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        // Gate out ambient room noise: anything quieter than `gate` reads as
        // silence, so the meter stays flat until you actually speak. The speech
        // band (gate → 0 dB) maps onto 0...1 with a mild curve.
        let gate: Float = -38
        let linear = max(0, min(1, (decibels - gate) / -gate))
        let normalized = pow(linear, 1.4)
        self.meterSamples.removeFirst()
        self.meterSamples.append(CGFloat(normalized))
      }
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
    elapsedTime = recorder?.currentTime ?? elapsedTime
  }
}
