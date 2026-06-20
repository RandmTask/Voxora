import MessageUI
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class VoiceSynapseStore {
  var notes: [AudioNote] = []
  var prompts: [PromptTemplate] = []
  var pendingEmailDraft: EmailDraft?
  var errorMessage: String?
  var isProcessing = false
  var selectedRoute: DeepLinkRoute?

  private let container: ModelContainer
  private let context: ModelContext
  private let keychainStore = KeychainStore()
  private let transcriber = SpeechTranscriber()
  private let processor: AIProcessingCoordinator

  init(container: ModelContainer) {
    self.container = container
    context = ModelContext(container)
    processor = AIProcessingCoordinator(keychainStore: keychainStore)
  }

  func prepare() async {
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

  func ingestTransferredAudio(fileURL: URL, metadata: [String: Any]) {
    do {
      let noteID = UUID(uuidString: metadata[TransferMetadata.noteID] as? String ?? "") ?? UUID()
      let createdAt = metadata[TransferMetadata.createdAt] as? Date ?? .now
      let tag = metadata[TransferMetadata.tag] as? String
      let duration = metadata[TransferMetadata.duration] as? Double ?? 0
      let fileExtension = metadata[TransferMetadata.fileExtension] as? String ?? fileURL.pathExtension
      let copiedURL = try AudioFileStore.copyAudioFile(from: fileURL, noteID: noteID, fileExtension: fileExtension)
      let note = notes.first(where: { $0.id == noteID }) ?? AudioNote(id: noteID)
      note.timestamp = createdAt
      note.transcriptText = ""
      note.transformedOutputText = ""
      note.processingStatus = .uploading
      note.tag = tag
      note.audioFileName = copiedURL.lastPathComponent
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

  func transform(_ note: AudioNote, kind: PromptKind) async {
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
      let result = try await processor.transform(text: note.transcriptText, using: template)
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
      errorMessage = VoiceSynapseAPIError.mailUnavailable.localizedDescription
      return
    }

    let body = [note.transcriptText, note.transformedOutputText]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")

    pendingEmailDraft = EmailDraft(
      subject: note.tag.flatMap { $0.isEmpty ? nil : $0 } ?? "VoiceSynapse Note",
      body: body
    )
  }

  func dismissEmailDraft() {
    pendingEmailDraft = nil
  }

  private func process(note: AudioNote) async {
    isProcessing = true
    note.processingStatus = .transcribing
    saveContext()

    do {
      let audioURL = try AudioFileStore.directoryURL().appending(path: note.audioFileName)
      let transcript = try await transcriber.transcribeAudio(at: audioURL)
      note.transcriptText = transcript
      note.processingStatus = .ready
      saveContext()
      reload()
    } catch {
      note.processingStatus = .idle
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
