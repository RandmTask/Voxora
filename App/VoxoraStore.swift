import AVFoundation
import Observation
import SwiftData
import SwiftUI
import UIKit

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
  /// When on, every new recording transcribes with Whisper if its model is installed,
  /// regardless of length. Off keeps Apple Speech as the instant default for short notes.
  var preferWhisperForAll = false {
    didSet {
      UserDefaults.standard.set(
        preferWhisperForAll,
        forKey: AppPreferences.preferWhisperForAllKey
      )
    }
  }
  /// Which Whisper model variant to use for on-device transcription.
  var whisperModelVariant: WhisperModelStore.Variant = WhisperModelStore.recommendedVariant {
    didSet {
      UserDefaults.standard.set(
        whisperModelVariant.rawValue,
        forKey: AppPreferences.whisperModelVariantKey
      )
    }
  }

  private let container: ModelContainer
  private let context: ModelContext
  private let keychainStore = KeychainStore()
  private let transcriber = SpeechTranscriber()
  private let whisperTranscriber = WhisperTranscriber()
  let whisperModels = WhisperModelStore.shared
  private let cloudTranscriber = CloudAudioTranscriber()
  private let processor: AIProcessingCoordinator
  private var processingNoteIDs = Set<UUID>()

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
    preferWhisperForAll = UserDefaults.standard.bool(
      forKey: AppPreferences.preferWhisperForAllKey
    )
    whisperModelVariant = WhisperModelStore.Variant(
      rawValue: UserDefaults.standard.string(
        forKey: AppPreferences.whisperModelVariantKey
      ) ?? ""
    ) ?? WhisperModelStore.recommendedVariant
  }

  func prepare() async {
    reload()
    migrateLegacyRecords()
    removeDuplicateRecords()
    seedPromptsIfNeeded()
    normalizeTooShortStatuses()
    reload()
    await resumePendingImports()
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
    let existingNote = notes.first(where: { $0.id == noteID })
    if let existingNote,
       existingNote.processingStatus == .ready,
       !existingNote.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return
    }

    let note = existingNote ?? AudioNote(id: noteID)
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

    if UIApplication.shared.applicationState == .active {
      Task {
        await processImportedAudio(noteID: noteID)
      }
    }
  }

  func importAudioFiles(_ urls: [URL]) async {
    var importedIDs: [UUID] = []
    for url in urls {
      let accessed = url.startAccessingSecurityScopedResource()
      defer { if accessed { url.stopAccessingSecurityScopedResource() } }

      let noteID = UUID()
      let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
      do {
        let destination = try AudioFileStore.copyAudioFile(
          from: url,
          noteID: noteID,
          fileExtension: ext
        )
        let duration = await audioDuration(at: destination)
        let createdAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
          .contentModificationDate ?? Date()

        let note = AudioNote(
          id: noteID,
          timestamp: createdAt,
          title: url.deletingPathExtension().lastPathComponent,
          processingStatus: .uploading,
          source: .imported,
          audioFileName: destination.lastPathComponent,
          duration: duration
        )
        context.insert(note)
        importedIDs.append(noteID)
      } catch {
        errorMessage = "Couldn't import \(url.lastPathComponent): \(error.localizedDescription)"
      }
    }

    guard !importedIDs.isEmpty else { return }
    saveContext()
    reload()
    Haptics.fire(.success)
    for noteID in importedIDs {
      await processImportedAudio(noteID: noteID)
    }
  }

  private func audioDuration(at url: URL) async -> TimeInterval {
    let asset = AVURLAsset(url: url)
    guard let duration = try? await asset.load(.duration) else { return 0 }
    let seconds = CMTimeGetSeconds(duration)
    return seconds.isFinite ? seconds : 0
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

  func resumePendingImports() async {
    guard UIApplication.shared.applicationState == .active else {
      return
    }

    reload()
    let pendingNoteIDs = notes
      .filter { $0.processingStatus == .uploading }
      .map(\.id)
    for noteID in pendingNoteIDs {
      await processImportedAudio(noteID: noteID)
    }
  }

  func retry(_ note: AudioNote) async {
    await process(note: note)
  }

  func retranscribe(_ note: AudioNote, using engine: TranscriptionEngine) async {
    guard !note.isTooShort else {
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
      case .whisper:
        transcript = try await transcribeWhisper(at: audioURL)
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

  /// Normalised tag name: trimmed and lowercased so tags stay tidy and dedupe
  /// case-insensitively. Used everywhere a tag name is created or renamed.
  static func normalizedTagName(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  /// First palette colour not already used by an existing tag, so new tags get a
  /// fresh colour. Falls back to cycling the palette once every colour is taken.
  func nextUnusedTagColor() -> String {
    let used = Set(tags.map { $0.colorHex.uppercased() })
    if let free = TagPalette.colors.first(where: { !used.contains($0.uppercased()) }) {
      return free
    }
    return TagPalette.colors[tags.count % TagPalette.colors.count]
  }

  /// Returns the tag with this name, creating it if needed. The returned tag is
  /// the live store instance so callers can assign it immediately.
  @discardableResult
  func upsertTag(named name: String, colorHex: String) -> NoteTag? {
    let cleaned = Self.normalizedTagName(name)
    guard !cleaned.isEmpty else { return nil }
    if let existing = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) {
      return existing
    }
    let tag = NoteTag(name: cleaned, colorHex: colorHex)
    context.insert(tag)
    saveContext()
    reload()
    return tags.first(where: { $0.id == tag.id }) ?? tag
  }

  func addTag(named name: String, colorHex: String = TagPalette.default, to note: AudioNote? = nil) {
    let cleaned = Self.normalizedTagName(name)
    guard !cleaned.isEmpty else { return }
    let tag = tags.first { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }
      ?? NoteTag(name: cleaned, colorHex: colorHex)
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

  /// Tags ordered for display: pinned first, then alphabetical.
  var sortedTags: [NoteTag] {
    tags.sorted {
      if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
      return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  func noteCount(for tag: NoteTag) -> Int {
    tagAssignments.filter { $0.tagID == tag.id }.count
  }

  func renameTag(_ tag: NoteTag, to name: String) {
    let cleaned = Self.normalizedTagName(name)
    guard !cleaned.isEmpty else { return }
    tag.name = cleaned
    tag.updatedAt = Date()
    saveContext()
    reload()
  }

  func setTagColor(_ tag: NoteTag, hex: String) {
    tag.colorHex = hex
    tag.updatedAt = Date()
    try? context.save()
    reload()
  }

  func toggleTagPinned(_ tag: NoteTag) {
    tag.isPinned.toggle()
    tag.updatedAt = Date()
    try? context.save()
    reload()
  }

  func toggleFavorite(_ note: AudioNote) {
    note.isFavorite.toggle()
    note.updatedAt = Date()
    Haptics.fire(.light)
    saveContext()
    reload()
  }

  func addAction() -> PromptTemplate {
    let action = PromptTemplate(
      kind: .custom,
      title: "",
      promptBody: "",
      sortOrder: (prompts.map(\.sortOrder).max() ?? -1) + 1
    )
    context.insert(action)
    saveContext()
    reload()
    return prompts.first(where: { $0.id == action.id }) ?? action
  }

  func reorderActions(from source: IndexSet, to destination: Int) {
    var ordered = prompts
    ordered.move(fromOffsets: source, toOffset: destination)
    for (index, prompt) in ordered.enumerated() {
      prompt.sortOrder = index
      prompt.updatedAt = Date()
    }
    saveContext()
    reload()
  }

  func deleteOutput(_ output: GeneratedOutput) {
    context.delete(output)
    saveContext()
    reload()
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
      Haptics.fire(.error)
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

  /// Merges several notes' transcripts into one new note, leaving the originals
  /// untouched. Audio isn't combined — the new note is transcript-only so AI
  /// actions (summaries etc.) can run across the whole set. Returns the new note.
  @discardableResult
  func combineNotes(_ notes: [AudioNote]) -> AudioNote? {
    let ordered = notes.sorted { $0.timestamp < $1.timestamp }
    guard ordered.count > 1 else { return nil }

    let combinedTranscript = ordered
      .map { note in
        let title = note.displayTitle
        let body = note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? "## \(title)" : "## \(title)\n\(body)"
      }
      .joined(separator: "\n\n")

    let merged = AudioNote(
      timestamp: Date(),
      title: "Combined note",
      transcriptText: combinedTranscript,
      processingStatus: .ready,
      source: .either,
      duration: ordered.reduce(0) { $0 + $1.duration }
    )
    context.insert(merged)

    // Carry over the union of the sources' tags so the combined note stays findable.
    let tagIDs = Set(ordered.flatMap { tags(for: $0).map(\.id) })
    for tagID in tagIDs {
      context.insert(NoteTagAssignment(noteID: merged.id, tagID: tagID))
    }

    saveContext()
    reload()
    Haptics.fire(.success)
    return notes.first(where: { $0.id == merged.id }) ?? merged
  }

  private func process(note: AudioNote) async {
    guard !note.isTooShort else {
      note.processingStatus = .tooShort
      saveContext()
      reload()
      return
    }

    guard UIApplication.shared.applicationState == .active else {
      note.processingStatus = .uploading
      saveContext()
      reload()
      return
    }

    guard processingNoteIDs.insert(note.id).inserted else {
      return
    }
    defer {
      processingNoteIDs.remove(note.id)
      isProcessing = !processingNoteIDs.isEmpty
    }

    isProcessing = true
    note.processingStatus = .transcribing
    saveContext()

    do {
      let audioURL = try AudioFileStore.directoryURL().appending(path: note.audioFileName)
      try validateAudioFile(at: audioURL)
      let transcript = try await transcribeNewRecording(note, at: audioURL)
      let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
      note.transcriptText = cleanedTranscript
      note.processingStatus = cleanedTranscript.isEmpty ? .empty : .ready
      note.updatedAt = Date()
      saveContext()
      reload()
      if !cleanedTranscript.isEmpty {
        Haptics.fire(.success)
        await runPostTranscriptionAutomation(for: note)
      }
    } catch {
      note.processingStatus = UIApplication.shared.applicationState == .active
        ? .failed
        : .uploading
      saveContext()
      reload()
      if UIApplication.shared.applicationState == .active {
        Haptics.fire(.error)
        errorMessage = error.localizedDescription
      }
    }
  }

  private func validateAudioFile(at url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path()) else {
      throw NSError(
        domain: "VoxoraAudio",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "The transferred recording file is missing."]
      )
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: url.path())
    let fileSize = attributes[.size] as? NSNumber
    guard fileSize?.intValue ?? 0 > 0 else {
      throw NSError(
        domain: "VoxoraAudio",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "The transferred recording file is empty."]
      )
    }
  }

  /// Three-tier routing for a new recording (see CLAUDE_Voxora.md):
  /// Apple Speech is the instant default for short notes; long notes (or the global
  /// "Prefer Whisper" toggle) route to Whisper when its model is installed; otherwise
  /// Apple Speech still handles it (and the user can retranscribe to a cloud engine).
  private func transcribeNewRecording(_ note: AudioNote, at url: URL) async throws -> String {
    if shouldUseWhisper(for: note),
       let folder = whisperModels.installedFolderURL(for: whisperModelVariant) {
      return try await whisperTranscriber.transcribeAudio(
        at: url,
        variant: whisperModelVariant,
        modelFolder: folder
      )
    }
    return try await transcribeAppleAudio(at: url)
  }

  private func shouldUseWhisper(for note: AudioNote) -> Bool {
    guard whisperModels.installedFolderURL(for: whisperModelVariant) != nil else { return false }
    if preferWhisperForAll { return true }
    return note.duration > AppPreferences.longRecordingThresholdSeconds
  }

  /// Transcribe with the selected Whisper model, validating presence at call time.
  private func transcribeWhisper(at url: URL) async throws -> String {
    guard let folder = whisperModels.installedFolderURL(for: whisperModelVariant) else {
      throw WhisperTranscriber.WhisperError.modelMissing(whisperModelVariant)
    }
    return try await whisperTranscriber.transcribeAudio(
      at: url,
      variant: whisperModelVariant,
      modelFolder: folder
    )
  }

  private func transcribeAppleAudio(at url: URL) async throws -> String {
    var lastError: Error?
    for attempt in 0..<2 {
      guard UIApplication.shared.applicationState == .active else {
        throw NSError(
          domain: "VoxoraSpeech",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Transcription will resume when Voxora is active."]
        )
      }

      do {
        return try await transcriber.transcribeAudio(at: url)
      } catch {
        lastError = error
        if attempt == 0 {
          try await Task.sleep(for: .milliseconds(750))
        }
      }
    }
    throw lastError ?? NSError(
      domain: "VoxoraSpeech",
      code: 4,
      userInfo: [NSLocalizedDescriptionKey: "Speech recognition could not process this recording."]
    )
  }

  private func saveContext() {
    do {
      try context.save()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func normalizeTooShortStatuses() {
    var changed = false
    for note in notes where note.isTooShort && note.processingStatus != .tooShort {
      note.processingStatus = .tooShort
      note.updatedAt = Date()
      changed = true
    }
    if changed {
      saveContext()
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
    normalizePromptOrder()
  }

  private func normalizeStarterPromptTitles() {
    let legacyPromptBodies: [UUID: String] = [
      PromptKind.todo.starterID: """
      Transform the transcript into an actionable checklist.
      Convert implied work into concrete tasks.
      Output markdown checkboxes only.
      """,
      PromptKind.numbered.starterID: """
      Distill the transcript into a concise numbered list.
      Preserve important names, commitments, dates, and sequence.
      """,
      PromptKind.bullets.starterID: """
      Distill the transcript into a clean hierarchy of bulleted points.
      Preserve important names, commitments, and dates.
      """,
      PromptKind.custom.starterID: """
      Summarize the transcript into key takeaways, then draft the most useful next artifact for the user.
      Keep the result concise and structured.
      """
    ]
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
                ["Custom", "Custom Action"].contains(prompt.title) {
        prompt.title = PromptKind.custom.defaultTitle
        changed = true
      }

      if let legacyBody = legacyPromptBodies[prompt.id],
         prompt.promptBody.trimmingCharacters(in: .whitespacesAndNewlines)
           == legacyBody.trimmingCharacters(in: .whitespacesAndNewlines) {
        prompt.promptBody = PromptKind(rawValue: prompt.kindRawValue)?.defaultPrompt
          ?? prompt.promptBody
        changed = true
      }
    }
    if changed {
      saveContext()
      reload()
    }
  }

  private func normalizePromptOrder() {
    let starterOrder: [UUID: Int] = [
      PromptKind.custom.starterID: 0,
      PromptKind.todo.starterID: 1,
      PromptKind.bullets.starterID: 2,
      PromptKind.numbered.starterID: 3
    ]
    var changed = false
    let customActions = prompts
      .filter { starterOrder[$0.id] == nil }
      .sorted {
        if $0.sortOrder == $1.sortOrder {
          return $0.createdAt < $1.createdAt
        }
        return $0.sortOrder < $1.sortOrder
      }

    for prompt in prompts {
      guard let order = starterOrder[prompt.id], prompt.sortOrder != order else {
        continue
      }
      prompt.sortOrder = order
      changed = true
    }

    for (offset, prompt) in customActions.enumerated() {
      let order = offset + starterOrder.count
      guard prompt.sortOrder != order else { continue }
      prompt.sortOrder = order
      changed = true
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
    if let existing = generatedOutputs.first(where: {
      $0.noteID == note.id && $0.actionID == action.id
    }) {
      existing.content = result
      existing.createdAt = Date()
      existing.actionTitle = action.title
    } else {
      context.insert(GeneratedOutput(
        noteID: note.id,
        actionID: action.id,
        actionTitle: action.title,
        content: result
      ))
    }
    note.transformedOutputText = result
    note.processingStatus = .ready
    note.updatedAt = Date()
    saveContext()
    reload()
  }

  private func runPostTranscriptionAutomation(for note: AudioNote) async {
    if let spoken = extractExplicitTitle(from: note.transcriptText) {
      note.title = spoken
      note.updatedAt = Date()
      saveContext()
      reload()
    } else if note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

  private func extractExplicitTitle(from transcript: String) -> String? {
    let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let pattern = #"^(?:title|subject)[\s:]+(.{3,80}?)(?:[,.\n]|$)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
          let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
          let range = Range(match.range(at: 1), in: trimmed)
    else { return nil }
    return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
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
