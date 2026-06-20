import Foundation
import Speech

actor SpeechTranscriber {
  func transcribeAudio(at url: URL) async throws -> String {
    let status = await requestAuthorizationIfNeeded()
    guard status == .authorized else {
      throw NSError(
        domain: "VoiceSynapseSpeech",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission was denied."]
      )
    }

    guard let recognizer = SFSpeechRecognizer() else {
      throw NSError(
        domain: "VoiceSynapseSpeech",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Speech recognition is unavailable for the current locale."]
      )
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    return try await withCheckedThrowingContinuation { continuation in
      recognizer.recognitionTask(with: request) { result, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        guard let result, result.isFinal else {
          return
        }

        continuation.resume(returning: result.bestTranscription.formattedString)
      }
    }
  }

  private func requestAuthorizationIfNeeded() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
  }
}
