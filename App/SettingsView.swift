import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SettingsView: View {
  @Bindable var store: VoxoraStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage(AppPreferences.appearanceKey) private var appearanceRawValue = AppTheme.dark.rawValue
  @AppStorage(AppPreferences.showSourceIconKey) private var showSourceIcon = true
  @AppStorage(AppPreferences.whisperWiFiOnlyDownloadsKey) private var whisperWiFiOnly = true
  @State private var providerDrafts: [AIProvider: String] = [:]
  @State private var editingAction: PromptTemplate?
  @State private var editingAutomation: AutomationProfile?
  @State private var pendingActionDelete: PromptTemplate?
  @State private var pendingAutomationDelete: AutomationProfile?
  @State private var pendingTagDelete: NoteTag?
  @State private var newTagDraft = ""
  @State private var newTagColor = TagPalette.default
  @State private var renamingTag: NoteTag?
  @State private var renameDraft = ""
  @State private var pendingLargeDownload: WhisperModelStore.Variant?
  @State private var pendingActivateDownload: WhisperModelStore.Variant?
  @State private var pendingDeleteVariant: WhisperModelStore.Variant?

  private var availableProviders: [AIProvider] {
    #if canImport(FoundationModels)
    if #available(iOS 26, *) {
      guard case .available = SystemLanguageModel.default.availability else {
        return AIProvider.allCases.filter { $0 != .appleIntelligence }
      }
      return AIProvider.allCases
    }
    #endif
    return AIProvider.allCases.filter { $0 != .appleIntelligence }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Appearance") {
          Picker("Theme", selection: $appearanceRawValue) {
            ForEach(AppTheme.allCases) { theme in
              Text(theme.title).tag(theme.rawValue)
            }
          }
          .pickerStyle(.menu)
        }

        Section("Recording controls") {
          Picker("iPhone tap action", selection: Binding(
            get: { store.phonePrimaryButtonBehavior },
            set: { store.phonePrimaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
          .pickerStyle(.menu)

          Picker("Apple Watch tap action", selection: Binding(
            get: { store.watchPrimaryButtonBehavior },
            set: { store.watchPrimaryButtonBehavior = $0 }
          )) {
            ForEach(PrimaryButtonBehavior.allCases) { behavior in
              Text(behavior.title).tag(behavior)
            }
          }
          .pickerStyle(.menu)
        }

        Section("Preferences") {
          NavigationLink {
            emailSettings
          } label: {
            settingsRow("Email", systemImage: "envelope")
          }

          NavigationLink {
            aiModelSettings
          } label: {
            settingsRow(
              "AI Model",
              systemImage: "apple.intelligence",
              detail: store.defaultAIProvider.title,
              tint: store.defaultAIProvider.tint
            )
          }

          NavigationLink {
            transcriptionSettings
          } label: {
            settingsRow(
              "Transcription",
              systemImage: "waveform",
              detail: store.preferWhisperForAll ? "Whisper" : "Apple Speech",
              tint: .indigo
            )
          }
        }

        Section("Organize and automate") {
          NavigationLink {
            aiActionsSettings
          } label: {
            settingsRow("AI Actions", systemImage: "sparkles", detail: "\(store.prompts.count)")
          }

          NavigationLink {
            automationsSettings
          } label: {
            settingsRow(
              "Automations",
              systemImage: "bolt.badge.clock",
              detail: "\(store.automationProfiles.count)"
            )
          }

          NavigationLink {
            tagsSettings
          } label: {
            settingsRow("Tags", systemImage: "tag", detail: "\(store.tags.count)")
          }
        }

        Section("Advanced") {
          NavigationLink {
            advancedSettings
          } label: {
            settingsRow("Advanced", systemImage: "gearshape.2")
          }
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            store.persistChanges()
            dismiss()
          }
        }
      }
      .task {
        for provider in AIProvider.allCases where provider.requiresAPIKey {
          providerDrafts[provider] = store.apiKey(for: provider)
        }
      }
      .sheet(item: $editingAction) { prompt in
        NavigationStack {
          ScrollView {
            PromptTemplateEditorCard(
              prompt: prompt,
              defaultProvider: store.defaultAIProvider,
              onDelete: {
                editingAction = nil
                pendingActionDelete = prompt
              }
            )
            .padding(20)
          }
          .navigationTitle(prompt.title.isEmpty ? "AI Action" : prompt.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") {
                store.persistChanges()
                editingAction = nil
              }
            }
          }
        }
      }
      .sheet(item: $editingAutomation) { profile in
        NavigationStack {
          Form {
            AutomationProfileEditorCard(
              profile: profile,
              actions: store.prompts,
              defaultProvider: store.defaultAIProvider,
              onDelete: {
                editingAutomation = nil
                pendingAutomationDelete = profile
              }
            )
          }
          .navigationTitle(profile.title.isEmpty ? "Automation" : profile.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") {
                store.persistChanges()
                editingAutomation = nil
              }
            }
          }
        }
      }
      .confirmationDialog(
        "Delete this AI action?",
        isPresented: Binding(
          get: { pendingActionDelete != nil },
          set: { if !$0 { pendingActionDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Action", role: .destructive) {
          if let action = pendingActionDelete {
            store.deleteAction(action)
          }
          pendingActionDelete = nil
        }
        Button("Cancel", role: .cancel) {}
      }
      .confirmationDialog(
        "Delete this automation?",
        isPresented: Binding(
          get: { pendingAutomationDelete != nil },
          set: { if !$0 { pendingAutomationDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Automation", role: .destructive) {
          if let profile = pendingAutomationDelete {
            store.deleteAutomationProfile(profile)
          }
          pendingAutomationDelete = nil
        }
        Button("Cancel", role: .cancel) {}
      }
      .confirmationDialog(
        "Delete this tag?",
        isPresented: Binding(
          get: { pendingTagDelete != nil },
          set: { if !$0 { pendingTagDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete Tag", role: .destructive) {
          if let tag = pendingTagDelete {
            store.deleteTag(tag)
          }
          pendingTagDelete = nil
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("The tag will be removed from notes, but no notes will be deleted.")
      }
    }
  }

  // MARK: - Sub-pages

  private var emailSettings: some View {
    Form {
      Section("Default Recipient") {
        TextField("e.g. you@example.com", text: Binding(
          get: { store.defaultEmailRecipient },
          set: { store.defaultEmailRecipient = $0 }
        ))
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .keyboardType(.emailAddress)
      }

      Section("Subject Prefix") {
        TextField("e.g. Memo", text: Binding(
          get: { store.emailSubjectPrefix },
          set: { store.emailSubjectPrefix = $0 }
        ))
      }
    }
    .navigationTitle("Email Settings")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var aiModelSettings: some View {
    Form {
      Section {
        Picker("AI Provider", selection: Binding(
          get: { store.defaultAIProvider },
          set: { store.defaultAIProvider = $0 }
        )) {
          ForEach(availableProviders) { provider in
            Text(provider.title).tag(provider)
          }
        }
        .pickerStyle(.menu)
        .tint(store.defaultAIProvider.tint)

        if store.defaultAIProvider.requiresAPIKey {
          Label(
            "Development only: raw API keys require a protected backend before TestFlight.",
            systemImage: "exclamationmark.triangle.fill"
          )
          .font(.caption)
          .foregroundStyle(.red)

          SecureField("API key", text: Binding(
            get: { providerDrafts[store.defaultAIProvider] ?? "" },
            set: { providerDrafts[store.defaultAIProvider] = $0 }
          ))
          .textContentType(.password)

          Button("Save API Key") {
            saveSelectedAPIKey()
          }
        } else {
          Label(
            "Runs privately on-device — no API key required.",
            systemImage: "apple.intelligence"
          )
          .foregroundStyle(.blue)
        }

        Button("Test \(store.defaultAIProvider.title)") {
          saveSelectedAPIKey()
          Task { await store.testProvider(store.defaultAIProvider) }
        }

        if let result = store.providerTestResults[store.defaultAIProvider] {
          Text(result)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle("AI Model")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var transcriptionSettings: some View {
    Form {
      Section {
        Toggle("Prefer Whisper for everything", isOn: Binding(
          get: { store.preferWhisperForAll },
          set: { store.preferWhisperForAll = $0 }
        ))
      } header: {
        Text("Engine")
      } footer: {
        Text("Apple Speech is the instant default and handles short notes well, but truncates past ~60 seconds. Long recordings automatically use Whisper when its model is installed. Turn this on to use Whisper for every recording.")
      }

      Section {
        Picker("Active model", selection: Binding(
          get: { store.whisperModelVariant },
          set: { store.whisperModelVariant = $0 }
        )) {
          ForEach(WhisperModelStore.Variant.allCases) { variant in
            Text(variant.title).tag(variant)
          }
        }
        Toggle("Download over Wi-Fi only", isOn: $whisperWiFiOnly)
        if !store.whisperModels.isInstalled(store.whisperModelVariant) {
          Label(
            "Not downloaded yet — download it below to use Whisper.",
            systemImage: "exclamationmark.circle"
          )
          .font(.caption)
          .foregroundStyle(.orange)
        }
      } header: {
        Text("Whisper model")
      } footer: {
        Text("Leave Wi-Fi only on to avoid downloading large models on cellular.")
      }

      Section {
        ForEach(WhisperModelStore.Variant.allCases) { variant in
          whisperModelRow(variant)
        }
      } header: {
        Text("On-device models")
      } footer: {
        Text("Models run entirely on your iPhone — audio never leaves the device, with no per-minute cost. iPhone/iPad only; Watch recordings transcribe on your phone. Tap a downloaded model's icon to remove it.")
      }
    }
    .navigationTitle("Transcription")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: store.whisperModelVariant) { _, newVariant in
      // Prompt to download an active model that isn't installed yet.
      if !store.whisperModels.isInstalled(newVariant),
         store.whisperModels.downloadingVariant != newVariant {
        pendingActivateDownload = newVariant
      }
    }
    .alert(
      "Download \(pendingLargeDownload?.title ?? "") model?",
      isPresented: Binding(
        get: { pendingLargeDownload != nil },
        set: { if !$0 { pendingLargeDownload = nil } }
      ),
      presenting: pendingLargeDownload
    ) { variant in
      Button("Download \(variant.sizeDescription)") {
        startWhisperDownload(variant)
        pendingLargeDownload = nil
      }
      Button("Cancel", role: .cancel) { pendingLargeDownload = nil }
    } message: { variant in
      Text("This model is \(variant.sizeDescription). Only download it if your device has room to spare.")
    }
    .alert(
      "Download \(pendingActivateDownload?.title ?? "") model?",
      isPresented: Binding(
        get: { pendingActivateDownload != nil },
        set: { if !$0 { pendingActivateDownload = nil } }
      ),
      presenting: pendingActivateDownload
    ) { variant in
      Button("Download \(variant.sizeDescription)") {
        startWhisperDownload(variant)
        pendingActivateDownload = nil
      }
      Button("Cancel", role: .cancel) { pendingActivateDownload = nil }
    } message: { variant in
      Text("The active model must be downloaded before Whisper can transcribe.")
    }
    .alert(
      "Remove \(pendingDeleteVariant?.title ?? "") model?",
      isPresented: Binding(
        get: { pendingDeleteVariant != nil },
        set: { if !$0 { pendingDeleteVariant = nil } }
      ),
      presenting: pendingDeleteVariant
    ) { variant in
      Button("Remove (\(variant.sizeDescription))", role: .destructive) {
        store.whisperModels.delete(variant)
        pendingDeleteVariant = nil
      }
      Button("Cancel", role: .cancel) { pendingDeleteVariant = nil }
    } message: { variant in
      Text("You can download it again later.")
    }
    .alert(
      "Download unavailable",
      isPresented: Binding(
        get: { store.whisperModels.lastErrorMessage != nil },
        set: { if !$0 { store.whisperModels.clearError() } }
      )
    ) {
      Button("OK", role: .cancel) { store.whisperModels.clearError() }
    } message: {
      Text(store.whisperModels.lastErrorMessage ?? "")
    }
  }

  @ViewBuilder
  private func whisperModelRow(_ variant: WhisperModelStore.Variant) -> some View {
    let isInstalled = store.whisperModels.isInstalled(variant)
    let isDownloading = store.whisperModels.downloadingVariant == variant
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(variant.title)
          if variant == WhisperModelStore.recommendedVariant {
            Text("Recommended")
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.blue.opacity(0.15), in: Capsule())
              .foregroundStyle(.blue)
          }
        }
        Text("\(variant.sizeDescription) · \(variant.detail)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      whisperModelControl(variant, isInstalled: isInstalled, isDownloading: isDownloading)
    }
    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
  }

  /// App Store–style control: outline icon to download, a filling ring while
  /// downloading, and a filled icon when installed — tap the filled icon to remove.
  @ViewBuilder
  private func whisperModelControl(
    _ variant: WhisperModelStore.Variant,
    isInstalled: Bool,
    isDownloading: Bool
  ) -> some View {
    let progress = store.whisperModels.downloadProgress[variant] ?? 0
    Button {
      if isDownloading {
        return
      } else if isInstalled {
        pendingDeleteVariant = variant
      } else if variant.isLargeDownload {
        pendingLargeDownload = variant
      } else {
        startWhisperDownload(variant)
      }
    } label: {
      ZStack {
        if isInstalled {
          Image(systemName: "arrow.down.circle.fill")
            .font(.title2)
            .foregroundStyle(.green)
        } else if isDownloading {
          DownloadClockIcon(progress: progress)
        } else {
          Image(systemName: "arrow.down.circle")
            .font(.title2)
            .foregroundStyle(.blue)
        }
      }
      .frame(width: 26, height: 26)
    }
    .buttonStyle(.borderless)
    .disabled(store.whisperModels.downloadingVariant != nil && !isInstalled)
  }

  private var aiActionsSettings: some View {
    List {
      ForEach(store.prompts) { prompt in
        Button {
          editingAction = prompt
        } label: {
          HStack(spacing: 14) {
            Image(systemName: prompt.iconName)
              .font(.title3)
              .foregroundStyle((prompt.providerOverride ?? store.defaultAIProvider).tint)
              .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
              Text(prompt.title)
                .foregroundStyle(.primary)
              Text((prompt.providerOverride ?? store.defaultAIProvider).title)
                .font(.caption)
                .foregroundStyle((prompt.providerOverride ?? store.defaultAIProvider).tint)
            }

            Spacer()

            if !prompt.isEnabled {
              Text("Off")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
        }
      }
      .onMove { from, to in
        store.reorderActions(from: from, to: to)
      }
    }
    .navigationTitle("AI Actions")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        EditButton()
        Button("Add Action", systemImage: "plus") {
          editingAction = store.addAction()
        }
      }
    }
  }

  private var automationsSettings: some View {
    List {
      ForEach(store.automationProfiles) { profile in
        Button {
          editingAutomation = profile
        } label: {
          HStack(spacing: 14) {
            Image(systemName: "bolt.badge.clock")
              .foregroundStyle(profile.isEnabled ? .blue : .secondary)
              .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
              Text(profile.title)
                .foregroundStyle(.primary)
              Text(
                "\(profile.isEnabled ? "On" : "Off") · " +
                (store.prompts.first(where: { $0.id == profile.actionID })?.title ?? "Unknown action")
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .overlay {
      if store.automationProfiles.isEmpty {
        ContentUnavailableView(
          "No Automations Yet",
          systemImage: "bolt.badge.clock",
          description: Text("Set one up and let Voxora do the grunt work while you stare out the window.")
        )
      }
    }
    .navigationTitle("Automations")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add Automation", systemImage: "plus") {
          store.addAutomationProfile()
          editingAutomation = store.automationProfiles.last
        }
      }
    }
  }

  private var tagsSettings: some View {
    List {
      if !store.tags.isEmpty {
        Section("Your Tags") {
          ForEach(store.sortedTags) { tag in
            TagManageRow(
              tag: tag,
              count: store.noteCount(for: tag),
              onColor: { store.setTagColor(tag, hex: $0) },
              onPin: { store.toggleTagPinned(tag) },
              onRename: { beginRenameTag(tag) },
              onDelete: { pendingTagDelete = tag }
            )
          }
        }
      }

      Section("New Tag") {
        HStack(spacing: 12) {
          TagColorSwatchPicker(selectedHex: $newTagColor)
          TextField("Tag name…", text: $newTagDraft)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(addNewTag)
          Button("Add", action: addNewTag)
            .disabled(newTagDraft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .overlay {
      if store.tags.isEmpty {
        ContentUnavailableView(
          "No Tags Yet",
          systemImage: "tag",
          description: Text("Tags are like folders, but without the guilt of never organising them. Add your first one above.")
        )
        .allowsHitTesting(false)
      }
    }
    .navigationTitle("Tags")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { newTagColor = store.nextUnusedTagColor() }
    .alert(
      renamingTag.map { "Rename \"\($0.name)\"" } ?? "Rename Tag",
      isPresented: Binding(
        get: { renamingTag != nil },
        set: { if !$0 { renamingTag = nil; renameDraft = "" } }
      )
    ) {
      TextField("Tag name", text: $renameDraft)
      Button("Save") {
        if let tag = renamingTag { store.renameTag(tag, to: renameDraft) }
        renamingTag = nil
        renameDraft = ""
      }
      .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      Button("Cancel", role: .cancel) { renamingTag = nil; renameDraft = "" }
    }
  }

  private func addNewTag() {
    let cleaned = newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    store.addTag(named: cleaned, colorHex: newTagColor)
    newTagDraft = ""
    newTagColor = store.nextUnusedTagColor()
  }

  private func beginRenameTag(_ tag: NoteTag) {
    renameDraft = tag.name
    renamingTag = tag
  }

  private var advancedSettings: some View {
    Form {
      Section {
        Toggle("Show recording source", isOn: $showSourceIcon)
      } footer: {
        Text("Displays an iPhone or Apple Watch icon on each note card.")
      }

      Section {
        Toggle("Include timestamp in exports", isOn: Binding(
          get: { store.includeTimestampInExports },
          set: { store.includeTimestampInExports = $0 }
        ))
      } footer: {
        Text("Adds the recording date to exported text and email content.")
      }
    }
    .navigationTitle("Advanced")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Helpers

  private func settingsRow(
    _ title: String,
    systemImage: String,
    detail: String? = nil,
    tint: Color = .blue
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .foregroundStyle(tint)
        .frame(width: 24)
      Text(title)
      Spacer()
      if let detail {
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }

  /// Download a Whisper model, then make it the active model once it's installed.
  private func startWhisperDownload(_ variant: WhisperModelStore.Variant) {
    Task {
      await store.whisperModels.download(variant, wifiOnly: whisperWiFiOnly)
      if store.whisperModels.isInstalled(variant) {
        store.whisperModelVariant = variant
      }
    }
  }

  private func saveSelectedAPIKey() {
    let provider = store.defaultAIProvider
    guard provider.requiresAPIKey else { return }
    store.saveAPIKey(providerDrafts[provider] ?? "", for: provider)
  }
}

/// A clock-style download indicator: a blue pie that fills with the real download
/// percentage. Before the first byte arrives (progress 0) the arrow gently pulses so
/// there's a sign of life \u2014 the pie never sweeps on its own, so the fill always
/// reflects the true progress rather than a misleading rotation.
private struct DownloadClockIcon: View {
  let progress: Double
  @State private var pulsing = false

  var body: some View {
    let clamped = max(0, min(1, progress))
    ZStack {
      Circle().fill(.blue.opacity(0.15))
      PieShape(progress: clamped)
        .fill(.blue)
        .animation(.easeInOut(duration: 0.3), value: clamped)
      Image(systemName: "arrow.down")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(clamped > 0 ? .white : .blue)
        .opacity(clamped > 0 ? 1 : (pulsing ? 0.3 : 1))
    }
    .frame(width: 22, height: 22)
    .onAppear {
      withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
        pulsing = true
      }
    }
  }
}

/// A filled circular sector (pie / clock wedge) from the top, clockwise.
private struct PieShape: Shape {
  var progress: Double
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    path.move(to: center)
    path.addArc(
      center: center,
      radius: radius,
      startAngle: .degrees(-90),
      endAngle: .degrees(-90 + 360 * max(0, min(1, progress))),
      clockwise: false
    )
    path.closeSubpath()
    return path
  }
}
