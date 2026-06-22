import Foundation
import WhisperKit

/// On-device transcription via WhisperKit (Core ML on the Neural Engine).
///
/// The model must already be downloaded — `WhisperModelStore` owns download/cache and
/// validates the folder at call time. This transcriber loads from a validated folder
/// and never triggers a download itself (`download: false`).
actor WhisperTranscriber {
  enum WhisperError: LocalizedError {
    case modelMissing(WhisperModelStore.Variant)
    case emptyResult

    var errorDescription: String? {
      switch self {
      case .modelMissing(let variant):
        "The \(variant.title) Whisper model isn't installed. Download it in Settings, then retry."
      case .emptyResult:
        "Whisper produced no transcript for this recording."
      }
    }
  }

  private var pipeline: WhisperKit?
  private var loadedVariant: WhisperModelStore.Variant?

  /// Transcribe `url` with a pre-downloaded model located at `modelFolder`.
  func transcribeAudio(
    at url: URL,
    variant: WhisperModelStore.Variant,
    modelFolder: URL
  ) async throws -> String {
    let pipeline = try await loadPipeline(variant: variant, modelFolder: modelFolder)
    let results = try await pipeline.transcribe(audioPath: url.path())
    let text = results
      .map(\.text)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw WhisperError.emptyResult }
    return text
  }

  /// Reuse a loaded pipeline when the variant is unchanged; reload on switch.
  private func loadPipeline(
    variant: WhisperModelStore.Variant,
    modelFolder: URL
  ) async throws -> WhisperKit {
    if let pipeline, loadedVariant == variant {
      return pipeline
    }
    let config = WhisperKitConfig(
      model: variant.rawValue,
      // Non-encoded path — "Application Support" has a literal space; `.path()`
      // would percent-encode it to "Application%20Support" and WhisperKit's file
      // lookups (MelSpectrogram.mlmodelc, etc.) would miss.
      modelFolder: modelFolder.path(percentEncoded: false),
      download: false
    )
    let pipeline = try await WhisperKit(config)
    self.pipeline = pipeline
    loadedVariant = variant
    return pipeline
  }
}
