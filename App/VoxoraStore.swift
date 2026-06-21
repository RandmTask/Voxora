import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class VoxoraStore {
  var notes: [AudioNote] = []
  var prompts: [PromptTemplate] = []
  var tags: [NoteTag] = []
  var tagAssignments: [NoteTagAssignment] = []
  var generatedOutputs: [GeneratedOutput] = []
  var automationProfiles: [AutomationProfile] = []
  var errorMessage: String?
  var isProcessing = false
  var selectedRoute: DeepLinkRoute?
  var providerTestResults: [AIProvider: String] = [:]
  var preferenceSync: (() -> Void)?
  var phonePrimaryButtonBehavior: PrimaryButtonBehavior = .pause {
    didSet {
      UserDefaults.standard.set(
        phonePrimaryButtonBehavior.rawValue,
        forKey: AppPreferences.phonePrimaryButtonBehaviorKey
      )
    }
  }
  var watchPrimaryButtonBehavior: PrimaryButtonBehavior = .pause {
    didSet {
      UserDefaults.standard.set(
        watchPrimaryButtonBehavior.rawValue,
        forKey: AppPreferences.watchPrimaryButtonBehaviorKey
      )
      preferenceSync?()
    }
  }
  var defaultAIProvider: AIProvider = .appleIntelligence {
    didSet {
      UserDefaults.standard.set(
        defaultAIProvider.rawValue,
        forKey: AppPreferences.defaultAIProviderKey
      )
    }
  }
  var defaultEmailRecipient = "" {
    didSet {
      UserDefaults.standard.set(
        defaultEmailRecipient,
        forKey: AppPreferences.defaultEmailRecipientKey
      )
    }
  }
  var emailSubjectPrefix = "" {
    didSet {
      UserDefaults.standard.set(
        emailSubjectPrefix,
        forKey: AppPreferences.emailSubjectPrefixKey
      )
    }
  }
  var includeTimestampInExports = false {
    didSet {
      UserDefaults.standard.set(
        includeTimestampInExports,
        forKey: AppPreferences.includeTimestampInExportsKey
      )
    }
  }

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
    phonePrimaryButtonBehavior = PrimaryButtonBehavior(
      rawValue: UserDefaults.standard.string(
        forKey: AppPreferences.phonePrimaryButtonBehaviorKey
      ) ?? ""
    ) ?? .pause
    watchPrimaryButtonBehavior = PrimaryButtonBehavior(
      rawValue: UserDefaults.standard.string(
        forKey: AppPreferences.watchPrimaryButtonBehaviorKey
      ) ?? ""
    ) ?? .pause
    defaultAIProvider = AIProvider(
      rawValue: UserDefaults.standard.string(
        forKey: AppPreferences.defaultAIProviderKey
      ) ?? ""
    ) ?? .appleIntelligence
    defaultEmailRecipient = UserDefaults.standard.string(
      forKey: AppPreferences.defaultEmailRecipientKey
    ) ?? ""
    emailSubjectPrefix = UserDefaults.standard.string(
      forKey: AppPreferences.emailSubjectPrefixKey
    ) ?? ""
    includeTimestampInExports = UserDefaults.standard.bool(
      forKey: AppPreferences.includeTimestampInExportsKey
    )
  }

  func prepare() async {
    reload()
    migrateLegacyRecords()
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

      let tombstones = try context.fetch(FetchDescriptor<DeletedAudioNote>())
      let deletedIDs = Set(tombstones.map(\.noteID))
      for note in notes where deletedIDs.contains(note.id) {
        context.delete(note)
      }
      if notes.contains(where: { deletedIDs.contains($0.id) }) {
        try context.save()
        notes = try context.fetch(noteDescriptor)
          .filter { !deletedIDs.contains($0.id) }
      }

      let promptDescriptor = FetchDescriptor<PromptTemplate>(
        sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
      )
      prompts = try context.fetch(promptDescriptor)

      tags = try context.fetch(FetchDescriptor<NoteTag>(
        sortBy: [SortDescriptor(\.name)]
      ))
      tagAssignments = try context.fetch(FetchDescriptor<NoteTagAssignment>())
      generatedOutputs = try context.fetch(FetchDescriptor<GeneratedOutput>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
      ))
      automationProfiles = try context.fetch(FetchDescriptor<AutomationProfile>(
        sortBy: [SortDescriptor(\.createdAt)]
      ))
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func ingestStagedAudio(fileURL: URL, metadata: [String: Any]) {
    let noteID = UUID(uuidString: metadata[TransferMetadata.noteID] as? String ?? "") ?? UUID()
    let createdAt = metadata[TransferMetadata.createdAt] as? Date ?? Date()
    let tag = metadata[TransferMetadata.tag] as? String
    let source: RecordingSource = tag == "Watch Capture" ? .watch : .iPhone
    let duration = metadata[TransferMetadata.duration] as? Double ?? 0
    let note = notes.first(where: { $0.id == noteID }) ?? AudioNote(id: noteID)
    note.timestamp = createdAt
    note.transcriptText = ""
    note.transformedOutputText = ""
    note.processingStatus = .uploading
    note.tag = tag
    note.source = source
    note.audioFileName = fileURL.lastPathComponent
    note.duration = duration
    note.updatedAt = Date()

    if !notes.contains(where: { $0.id == noteID }) {
      context.insert(note)
    }
    saveContext()
    reload()

    Task {
      await processImportedAudio(noteID: noteID)
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
      note.updatedAt = Date()
      saveContext()
      reload()
      if !cleaned.isEmpty {
        await runPostTranscriptionAutomation(for: note)
      }
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
      let selectedProvider = provider ?? template.providerOverride ?? defaultAIProvider
      let result = try await processor.transform(
        text: note.transcriptText,
        promptBody: template.promptBody,
        provider: selectedProvider
      )
      saveGeneratedOutput(result, for: note, action: template)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func runAction(_ action: PromptTemplate, on note: AudioNote) async {
    guard !note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    isProcessing = true
    defer { isProcessing = false }

    do {
      let result = try await processor.transform(
        text: note.transcriptText,
        promptBody: action.promptBody,
        provider: action.providerOverride ?? defaultAIProvider
      )
      saveGeneratedOutput(result, for: note, action: action)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func outputs(for note: AudioNote) -> [GeneratedOutput] {
    generatedOutputs.filter { $0.noteID == note.id }
  }

  func tags(for note: AudioNote) -> [NoteTag] {
    let tagIDs = Set(tagAssignments.filter { $0.noteID == note.id }.map(\.tagID))
    return tags.filter { tagIDs.contains($0.id) }
  }

  func setTag(_ tag: NoteTag, on note: AudioNote, isAssigned: Bool) {
    let existing = tagAssignments.first { $0.noteID == note.id && $0.tagID == tag.id }
    if isAssigned, existing == nil {
      context.insert(NoteTagAssignment(noteID: note.id, tagID: tag.id))
    } else if !isAssigned, let existing {
      context.delete(existing)
    }
    saveContext()
    reload()
  }

  func setTags(_ tagIDs: Set<UUID>, on note: AudioNote) {
    let current = tagAssignments.filter { $0.noteID == note.id }
    let currentIDs = Set(current.map(\.tagID))

    for assignment in current where !tagIDs.contains(assignment.tagID) {
      context.delete(assignment)
    }
    for tagID in tagIDs.subtracting(currentIDs) {
      context.insert(NoteTagAssignment(noteID: note.id, tagID: tagID))
    }
    saveContext()
    reload()
  }

  func addTag(named name: String, to note: AudioNote? = nil) {
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    let tag = tags.first { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }
      ?? NoteTag(name: cleaned)
    if !tags.contains(where: { $0.id == tag.id }) {
      context.insert(tag)
    }
    if let note,
       !tagAssignments.contains(where: { $0.noteID == note.id && $0.tagID == tag.id }) {
      context.insert(NoteTagAssignment(noteID: note.id, tagID: tag.id))
    }
    saveContext()
    reload()
  }

  func deleteTag(_ tag: NoteTag) {
    for assignment in tagAssignments where assignment.tagID == tag.id {
      context.delete(assignment)
    }
    context.delete(tag)
    saveContext()
    reload()
  }

  func toggleFavorite(_ note: AudioNote) {
    note.isFavorite.toggle()
    note.updatedAt = Date()
    saveContext()
    reload()
  }

  func addAction() -> PromptTemplate {
    let action = PromptTemplate(
      kind: .custom,
      title: "New Action",
      promptBody: PromptKind.custom.defaultPrompt,
      sortOrder: (prompts.map(\.sortOrder).max() ?? -1) + 1
    )
    context.insert(action)
    saveContext()
    reload()
    return prompts.first(where: { $0.id == action.id }) ?? action
  }

  func deleteAction(_ action: PromptTemplate) {
    guard prompts.count > 1 else {
      errorMessage = "Keep at least one AI action."
      return
    }
    for profile in automationProfiles where profile.actionID == action.id {
      profile.isEnabled = false
    }
    context.delete(action)
    saveContext()
    reload()
  }

  func addAutomationProfile() {
    guard let action = prompts.first else {
      errorMessage = "Create an AI action before adding an automation."
      return
    }
    context.insert(AutomationProfile(
      title: "New Automation",
      actionID: action.id
    ))
    saveContext()
    reload()
  }

  func deleteAutomationProfile(_ profile: AutomationProfile) {
    context.delete(profile)
    saveContext()
    reload()
  }

  func polishEmail(body: String, instructions: String) async -> String? {
    let source = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else {
      errorMessage = "Add some email content before polishing it."
      return nil
    }

    isProcessing = true
    defer { isProcessing = false }

    do {
      return try await processor.polishEmail(
        body: source,
        instructions: instructions,
        provider: defaultAIProvider
      )
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  func archive(_ note: AudioNote) {
    note.archivedAt = note.archivedAt == nil ? Date() : nil
    note.updatedAt = Date()
    saveContext()
    reload()
  }

  func delete(_ note: AudioNote) {
    do {
      try AudioFileStore.removeAudioFile(named: note.audioFileName)
      for assignment in tagAssignments where assignment.noteID == note.id {
        context.delete(assignment)
      }
      for output in generatedOutputs where output.noteID == note.id {
        context.delete(output)
      }
      context.insert(DeletedAudioNote(noteID: note.id))
      context.delete(note)
      saveContext()
      reload()
    } catch {
      errorMessage = error.localizedDescription
    }
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
      note.updatedAt = Date()
      saveContext()
      reload()
      if !cleanedTranscript.isEmpty {
        await runPostTranscriptionAutomation(for: note)
      }
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

    var seenPromptIDs = Set<UUID>()
    for prompt in prompts where !seenPromptIDs.insert(prompt.id).inserted {
      context.delete(prompt)
    }

    var seenAssignments = Set<String>()
    for assignment in tagAssignments {
      let key = "\(assignment.noteID.uuidString)|\(assignment.tagID.uuidString)"
      if !seenAssignments.insert(key).inserted {
        context.delete(assignment)
      }
    }

    var seenOutputIDs = Set<UUID>()
    for output in generatedOutputs where !seenOutputIDs.insert(output.id).inserted {
      context.delete(output)
    }

    saveContext()
    reload()
  }

  private func seedPromptsIfNeeded() {
    let existingKinds = Set(prompts.map(\.kindRawValue))
    for (index, kind) in PromptKind.allCases.enumerated() where !existingKinds.contains(kind.rawValue) {
      context.insert(PromptTemplate(id: kind.starterID, kind: kind, sortOrder: index))
    }
    saveContext()
    reload()
    normalizeStarterPromptTitles()
  }

  private func normalizeStarterPromptTitles() {
    var changed = false
    for prompt in prompts {
      if prompt.id == PromptKind.todo.starterID,
         prompt.title == "To-Do Transformer" {
        prompt.title = PromptKind.todo.defaultTitle
        changed = true
      } else if prompt.id == PromptKind.bullets.starterID,
                prompt.title == "Numbered/Bulleted List" {
        prompt.title = PromptKind.bullets.defaultTitle
        changed = true
      } else if prompt.id == PromptKind.custom.starterID,
                prompt.title == "Custom Action" {
        prompt.title = PromptKind.custom.defaultTitle
        changed = true
      }
    }
    if changed {
      saveContext()
      reload()
    }
  }

  private func migrateLegacyRecords() {
    var changed = false

    for note in notes {
      if note.tag == "archived", note.archivedAt == nil {
        note.archivedAt = note.timestamp
        note.tag = nil
        changed = true
      } else if note.tag == "Watch Capture", note.source != .watch {
        note.source = .watch
        changed = true
      }

      let legacyOutput = note.transformedOutputText.trimmingCharacters(in: .whitespacesAndNewlines)
      if !legacyOutput.isEmpty,
         !generatedOutputs.contains(where: { $0.id == note.id }) {
        context.insert(GeneratedOutput(
          id: note.id,
          noteID: note.id,
          actionID: PromptKind.custom.starterID,
          actionTitle: "Legacy Output",
          content: legacyOutput
        ))
        changed = true
      }
    }

    if changed {
      saveContext()
      reload()
    }
  }

  private func saveGeneratedOutput(
    _ result: String,
    for note: AudioNote,
    action: PromptTemplate
  ) {
    let output = GeneratedOutput(
      noteID: note.id,
      actionID: action.id,
      actionTitle: action.title,
      content: result
    )
    context.insert(output)
    note.transformedOutputText = result
    note.processingStatus = .ready
    note.updatedAt = Date()
    saveContext()
    reload()
  }

  private func runPostTranscriptionAutomation(for note: AudioNote) async {
    if note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      await generateTitle(for: note)
    }

    let matchingProfiles = automationProfiles.filter {
      $0.isEnabled && $0.source.matches(note.source)
    }
    for profile in matchingProfiles {
      if profile.generateTitle,
         note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        await generateTitle(for: note)
      }
      if let action = prompts.first(where: { $0.id == profile.actionID && $0.isEnabled }) {
        await runAction(action, on: note)
      }
    }
  }

  private func generateTitle(for note: AudioNote) async {
    do {
      let title = try await processor.generateTitle(
        text: note.transcriptText,
        provider: defaultAIProvider
      )
      guard !title.isEmpty else { return }
      note.title = title
      note.updatedAt = Date()
      saveContext()
      reload()
    } catch {
      // Title generation is helpful but must never make transcription fail.
    }
  }
}
