import Foundation
import Network
import Observation
import WhisperKit

/// Manages on-device Whisper model downloads for transcription.
///
/// Data-safety rules (see `CLAUDE_Voxora.md` → Whisper / on-device transcription):
/// - Models live under **Application Support**, never `Caches/` — iOS silently
///   evicts `Caches/` under storage pressure (the Just Press Record bug).
/// - Existence is validated with `FileManager.fileExists` **at call time**; a missing
///   folder (e.g. the user cleared storage) surfaces a re-download prompt rather than
///   failing silently.
/// - Model blobs are per-device caches, never synced to CloudKit / the app-group store.
@MainActor
@Observable
final class WhisperModelStore {
  static let shared = WhisperModelStore()

  /// A selectable Whisper model variant. `rawValue` is the WhisperKit variant name.
  enum Variant: String, CaseIterable, Identifiable {
    case tiny = "openai_whisper-tiny"
    case base = "openai_whisper-base"
    case small = "openai_whisper-small"
    case medium = "openai_whisper-medium"
    case large = "openai_whisper-large-v3-v20240930"

    var id: String { rawValue }

    /// Friendly name for the picker.
    var title: String {
      switch self {
      case .tiny: "Tiny"
      case .base: "Base"
      case .small: "Small"
      case .medium: "Medium"
      case .large: "Large"
      }
    }

    /// Approximate on-disk size, for the picker and the low-storage warning.
    var approximateMegabytes: Int {
      switch self {
      case .tiny: 75
      case .base: 145
      case .small: 480
      case .medium: 1500
      case .large: 3100
      }
    }

    var sizeDescription: String {
      approximateMegabytes >= 1000
        ? String(format: "~%.1f GB", Double(approximateMegabytes) / 1000)
        : "~\(approximateMegabytes) MB"
    }

    /// One-line tradeoff shown under each tier.
    var detail: String {
      switch self {
      case .tiny: "Fastest, lowest accuracy."
      case .base: "Recommended — good balance."
      case .small: "More accurate, slower."
      case .medium: "High accuracy. Large download."
      case .large: "Best accuracy. Very large; needs ample free space."
      }
    }

    /// Tiers we warn about before downloading on space-constrained devices.
    var isLargeDownload: Bool { approximateMegabytes >= 1000 }
  }

  static let recommendedVariant: Variant = .base

  private static let installedPathsKey = "whisper.installedModelPaths"

  /// Per-variant download progress, 0...1, while a download is in flight.
  private(set) var downloadProgress: [Variant: Double] = [:]
  /// The variant currently downloading, if any.
  private(set) var downloadingVariant: Variant?
  /// Last download error message, surfaced in Settings.
  private(set) var lastErrorMessage: String?
  /// Authoritative on-disk folder for each installed variant — the URL WhisperKit's
  /// `download()` actually returned (its layout is internal to HubApi, so we trust the
  /// return value rather than recomputing it). Persisted device-local; observed so the
  /// UI flips to "installed" the moment a download finishes.
  private(set) var installedFolderPaths: [Variant: String] = [:]

  private init() {
    if let stored = UserDefaults.standard.dictionary(forKey: Self.installedPathsKey) as? [String: String] {
      for (raw, path) in stored {
        if let variant = Variant(rawValue: raw) { installedFolderPaths[variant] = path }
      }
    }
  }

  /// Base directory WhisperKit downloads into. Lives in Application Support so it
  /// survives low-storage purges. Created lazily; never in `Caches/`.
  private func modelsBaseURL() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let base = support.appending(path: "WhisperModels", directoryHint: .isDirectory)
    if !FileManager.default.fileExists(atPath: base.path(percentEncoded: false)) {
      try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }
    return base
  }

  /// A non-empty directory at `path` (validated at call time).
  private func folderHasModel(atPath path: String) -> Bool {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
          isDirectory.boolValue else { return false }
    let contents = try? FileManager.default.contentsOfDirectory(atPath: path)
    return (contents?.isEmpty == false)
  }

  /// Validate presence **at call time** — the model folder must still exist on disk
  /// (it can be evicted/cleared by the user) and be non-empty.
  func isInstalled(_ variant: Variant) -> Bool {
    installedFolderURL(for: variant) != nil
  }

  /// Validated folder URL for transcription, or nil if the model is missing/evicted.
  func installedFolderURL(for variant: Variant) -> URL? {
    guard let path = installedFolderPaths[variant], folderHasModel(atPath: path) else { return nil }
    return URL(fileURLWithPath: path)
  }

  var installedVariants: [Variant] {
    Variant.allCases.filter { isInstalled($0) }
  }

  private func persistInstalledPaths() {
    let raw = Dictionary(uniqueKeysWithValues: installedFolderPaths.map { ($0.key.rawValue, $0.value) })
    UserDefaults.standard.set(raw, forKey: Self.installedPathsKey)
  }

  /// Download (or repair) a model variant, reporting progress.
  /// When `wifiOnly` is set, a cellular-only connection is refused with a clear message
  /// rather than silently consuming the user's data on a multi-hundred-MB download.
  func download(_ variant: Variant, wifiOnly: Bool) async {
    guard downloadingVariant == nil else { return }

    if wifiOnly, await isOnExpensiveConnection() {
      lastErrorMessage = "On cellular. Connect to Wi-Fi, or turn off “Wi-Fi only” to download on cellular."
      return
    }

    downloadingVariant = variant
    downloadProgress[variant] = 0
    lastErrorMessage = nil
    defer { downloadingVariant = nil }

    do {
      let base = try modelsBaseURL()
      // Trust the URL WhisperKit returns — its on-disk layout is internal to HubApi.
      let folderURL = try await WhisperKit.download(
        variant: variant.rawValue,
        downloadBase: base,
        useBackgroundSession: false,
        progressCallback: { [weak self] progress in
          Task { @MainActor in
            self?.downloadProgress[variant] = progress.fractionCompleted
          }
        }
      )
      let path = folderURL.path(percentEncoded: false)
      guard folderHasModel(atPath: path) else {
        // Loud, not silent: the download returned but the files aren't where expected.
        lastErrorMessage = "Downloaded \(variant.title) but couldn't find the model files at \(path)."
        downloadProgress[variant] = nil
        return
      }
      installedFolderPaths[variant] = path
      persistInstalledPaths()
      downloadProgress[variant] = 1
    } catch {
      lastErrorMessage = "\(variant.title) download failed: \(error.localizedDescription)"
      downloadProgress[variant] = nil
    }
  }

  /// True when the current network path is cellular or otherwise marked expensive.
  private func isOnExpensiveConnection() async -> Bool {
    await withCheckedContinuation { continuation in
      let monitor = NWPathMonitor()
      let queue = DispatchQueue(label: "WhisperModelStore.path")
      monitor.pathUpdateHandler = { path in
        let expensive = path.isExpensive || path.usesInterfaceType(.cellular)
        monitor.cancel()
        continuation.resume(returning: expensive)
      }
      monitor.start(queue: queue)
    }
  }

  /// Delete a downloaded model to reclaim space.
  func delete(_ variant: Variant) {
    if let path = installedFolderPaths[variant] {
      try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
    }
    installedFolderPaths[variant] = nil
    persistInstalledPaths()
    downloadProgress[variant] = nil
  }
}
