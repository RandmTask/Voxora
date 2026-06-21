import MessageUI
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class VoxoraStore {
  var notes: [AudioNote] = []
  var prompts: [PromptTemplate] = []
  var pendingEmailDraft: EmailDraft?
  var errorMessage: String?
  var isProcessing = false
  var selectedRoute: DeepLinkRoute?
  var providerTestResults: [AIProvider: String] = [:]
  var preferenceSync: (() -> Void)?

  private let container: ModelContainer
  private let context: ModelContext
  private let keychainStore = KeychainStore()
  private let transcriber = SpeechTranscriber()
  private let cloudTranscriber = CloudAudioTranscriber()
  private let processor: AIProcessingCoordinator

  init(container: ModelContainer) {
    self.container = container
    context = ModelContext(container)
    processor = AIProcessingCoordinator(keychainStore: keychainStore)
  }

  func prepare() async {
    reload()
    removeDuplicateRecords()
    seedPromptsIfNeeded()
    reload()
  }

  func handle(route: DeepLinkRoute) {
    selectedRoute = route
  }

  func apiKey(for provider: AIProvider) -> String {
    keychainStore.value(for: provider.keychainKey)
  }

  func persistChanges() {
    saveContext()
    reload()
  }

  func saveAPIKey(_ value: String, for provider: AIProvider) {
    keychainStore.save(value, for: provider.keychainKey)
  }

  var primaryButtonBehavior: PrimaryButtonBehavior {
    get {
      PrimaryButtonBehavior(
        rawValue: UserDefaults.standard.string(forKey: AppPreferences.primaryButtonBehaviorKey) ?? ""
      ) ?? .pause
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: AppPreferences.primaryButtonBehaviorKey)
      preferenceSync?()
    }
  }

  func testProvider(_ provider: AIProvider) async {
    do {
      let response = try await processor.test(provider: provider)
      providerTestResults[provider] = response
    } catch {
      providerTestResults[provider] = error.localizedDescription
    }
  }

  func prompt(for kind: PromptKind) -> PromptTemplate? {
    prompts.first(where: { $0.kind == kind })
  }

  func reload() {
    do {
      let noteDescriptor = FetchDescriptor<AudioNote>(
        sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
      )
      notes = try context.fetch(noteDescriptor)

      let promptDescriptor = FetchDescriptor<PromptTemplate>(
        sortBy: [SortDescriptor(\.kindRawValue)]
      )
      prompts = try context.fetch(promptDescriptor)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func ingestStagedAudio(fileURL: URL, metadata: [String: Any]) {
    do {
      let noteID = UUID(uuidString: metadata[TransferMetadata.noteID] as? String ?? "") ?? UUID()
      let createdAt = metadata[TransferMetadata.createdAt] as? Date ?? .now
      let tag = metadata[TransferMetadata.tag] as? String
      let duration = metadata[TransferMetadata.duration] as? Double ?? 0
      let note = notes.first(where: { $0.id == noteID }) ?? AudioNote(id: noteID)
      note.timestamp = createdAt
      note.transcriptText = ""
      note.transformedOutputText = ""
      note.processingStatus = .uploading
      note.tag = tag
      note.audioFileName = fileURL.lastPathComponent
      note.duration = duration

      if !notes.contains(where: { $0.id == noteID }) {
        context.insert(note)
      }
      saveContext()
      reload()

      Task {
        await processImportedAudio(noteID: noteID)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func ingestPhoneRecording(fileURL: URL, noteID: UUID, createdAt: Date, duration: TimeInterval) {
    ingestStagedAudio(
      fileURL: fileURL,
      metadata: [
        TransferMetadata.noteID: noteID.uuidString,
        TransferMetadata.createdAt: createdAt,
        TransferMetadata.tag: "iPhone Capture",
        TransferMetadata.duration: duration,
        TransferMetadata.fileExtension: fileURL.pathExtension
      ]
    )
  }

  func processImportedAudio(noteID: UUID) async {
    guard let note = notes.first(where: { $0.id == noteID }) else {
      reload()
      guard let note = notes.first(where: { $0.id == noteID }) else {
        return
      }
      await process(note: note)
      return
    }
    await process(note: note)
  }

  func retry(_ note: AudioNote) async {
    await process(note: note)
  }

  func retranscribe(_ note: AudioNote, using engine: TranscriptionEngine) async {
    guard note.duration >= 1 else {
      note.processingStatus = .tooShort
      saveContext()
      reload()
      return
    }

    isProcessing = true
    note.processingStatus = .transcribing
    saveContext()
    defer { isProcessing = false }

    do {
      let audioURL = try AudioFileStore.directoryURL().appending(path: note.audioFileName)
      let transcript: String
      switch engine {
      case .appleSpeech:
        transcript = try await transcriber.transcribeAudio(at: audioURL)
      case .gemini:
        transcript = try await cloudTranscriber.transcribe(
          audioURL: audioURL,
          engine: engine,
          apiKey: apiKey(for: .gemini)
        )
      case .openAI:
        transcript = try await cloudTranscriber.transcribe(
          audioURL: audioURL,
          engine: engine,
          apiKey: apiKey(for: .openAI)
        )
      }
      let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
      note.transcriptText = cleaned
      note.processingStatus = cleaned.isEmpty ? .empty : .ready
      saveContext()
      reload()
    } catch {
      note.processingStatus = .failed
      saveContext()
      errorMessage = error.localizedDescription
    }
  }

  func transform(_ note: AudioNote, kind: PromptKind, provider: AIProvider? = nil) async {
    guard let template = prompt(for: kind) else {
      return
    }

    if note.transcriptText.isEmpty {
      await process(note: note)
    }

    guard !note.transcriptText.isEmpty else {
      return
    }

    isProcessing = true
    defer { isProcessing = false }

    do {
      let result = try await processor.transform(
        text: note.transcriptText,
        using: template,
        provider: provider
      )
      note.transformedOutputText = result
      note.processingStatus = .ready
      saveContext()
      reload()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func archive(_ note: AudioNote) {
    note.tag = "archived"
    saveContext()
    reload()
  }

  func delete(_ note: AudioNote) {
    do {
      try AudioFileStore.removeAudioFile(named: note.audioFileName)
      context.delete(note)
      saveContext()
      reload()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func queueEmail(for note: AudioNote) {
    guard MFMailComposeViewController.canSendMail() else {
      errorMessage = VoxoraAPIError.mailUnavailable.localizedDescription
      return
    }

    let body = [note.transcriptText, note.transformedOutputText]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")

    pendingEmailDraft = EmailDraft(
      subject: note.tag.flatMap { $0.isEmpty ? nil : $0 } ?? "Voxora Note",
      body: body
    )
  }

  func dismissEmailDraft() {
    pendingEmailDraft = nil
  }

  private func process(note: AudioNote) async {
    guard note.duration >= 1 else {
      note.transcriptText = ""
      note.processingStatus = .tooShort
      saveContext()
      reload()
      return
    }

    isProcessing = true
    note.processingStatus = .transcribing
    saveContext()

    do {
      let audioURL = try AudioFileStore.directoryURL().appending(path: note.audioFileName)
      let transcript = try await transcriber.transcribeAudio(at: audioURL)
      let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
      note.transcriptText = cleanedTranscript
      note.processingStatus = cleanedTranscript.isEmpty ? .empty : .ready
      saveContext()
      reload()
    } catch {
      note.processingStatus = .failed
      saveContext()
      errorMessage = error.localizedDescription
    }

    isProcessing = false
  }

  private func saveContext() {
    do {
      try context.save()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func removeDuplicateRecords() {
    var seenNoteIDs = Set<UUID>()
    for note in notes where !seenNoteIDs.insert(note.id).inserted {
      context.delete(note)
    }

    var seenPromptKinds = Set<String>()
    for prompt in prompts where !seenPromptKinds.insert(prompt.kindRawValue).inserted {
      context.delete(prompt)
    }

    saveContext()
    reload()
  }

  private func seedPromptsIfNeeded() {
    let existingKinds = Set(prompts.map(\.kind))
    for kind in PromptKind.allCases where !existingKinds.contains(kind) {
      let provider: AIProvider
      switch kind {
      case .todo:
        provider = .gemini
      case .bullets:
        provider = .deepSeek
      case .custom:
        provider = .appleIntelligence
      }
      context.insert(PromptTemplate(kind: kind, preferredProvider: provider))
    }
    saveContext()
    reload()
  }
}
