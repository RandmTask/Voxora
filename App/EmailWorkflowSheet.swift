import MessageUI
import SwiftUI

struct EmailWorkflowSheet: View {
  private enum PolishStyle: String, CaseIterable, Identifiable {
    case concise = "Concise & professional"
    case friendly = "Friendly"
    case formal = "Formal"
    case actionFocused = "Action-focused"
    case custom = "Custom…"

    var id: String { rawValue }

    var instructions: String {
      switch self {
      case .concise: "Concise and professional"
      case .friendly: "Warm, friendly, and natural"
      case .formal: "Formal, polished, and respectful"
      case .actionFocused: "Clear, direct, and focused on decisions and next steps"
      case .custom: ""
      }
    }
  }

  private enum SubjectPart: String, CaseIterable, Identifiable {
    case prefix = "Prefix"
    case date = "Date"
    case time = "Time"
    case source = "Source"
    case tags = "Tags"

    var id: String { rawValue }

    var systemImage: String {
      switch self {
      case .prefix: "textformat"
      case .date: "calendar"
      case .time: "clock"
      case .source: "waveform"
      case .tags: "tag"
      }
    }
  }

  private enum BodyPreset: String, CaseIterable, Identifiable {
    case transcript = "Transcript"
    case latestOutput = "Latest AI"
    case transcriptAndLatest = "Both"
    case allOutputs = "All AI"

    var id: String { rawValue }

    var systemImage: String {
      switch self {
      case .transcript: "text.quote"
      case .latestOutput: "sparkles"
      case .transcriptAndLatest: "rectangle.2.swap"
      case .allOutputs: "square.stack.3d.up"
      }
    }
  }

  @Bindable var store: VoxoraStore
  var note: AudioNote

  @Environment(\.dismiss) private var dismiss
  @State private var recipient = ""
  @State private var cc = ""
  @State private var bcc = ""
  @State private var showsCc = false
  @State private var showsBcc = false
  @State private var subject = ""
  @State private var selectedSubjectParts: Set<SubjectPart> = []
  @State private var bodyPreset: BodyPreset = .transcriptAndLatest
  @State private var includesBodyTimestamp = false
  @State private var attachesTranscript = false
  @State private var polishStyle: PolishStyle = .concise
  @State private var customInstructions = ""
  @State private var emailBody = ""
  @State private var draft: EmailDraft?
  @State private var isPolishing = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Recipients") {
          HStack {
            TextField("To", text: $recipient)
              .textContentType(.emailAddress)
              .textInputAutocapitalization(.never)
              .keyboardType(.emailAddress)

            Menu {
              if !defaultRecipient.isEmpty {
                Button("Use Default Recipient", systemImage: "person.crop.circle.badge.checkmark") {
                  recipient = defaultRecipient
                }
              }
              Button("Add Cc", systemImage: "person.2") {
                showsCc = true
              }
              Button("Add Bcc", systemImage: "eye.slash") {
                showsBcc = true
              }
            } label: {
              Image(systemName: "plus.circle.fill")
                .font(.title3)
            }
            .accessibilityLabel("Recipient options")
          }

          if showsCc {
            addressField("Cc", text: $cc)
          }

          if showsBcc {
            addressField("Bcc", text: $bcc)
          }
        }

        Section("Subject") {
          TextField("Subject", text: $subject)

          fadingChipScroller {
            ForEach(SubjectPart.allCases) { part in
              optionChip(
                part.rawValue,
                systemImage: part.systemImage,
                isSelected: selectedSubjectParts.contains(part),
                isEnabled: subjectPartIsAvailable(part)
              ) {
                toggleSubjectPart(part)
              }
            }
          }
        }

        Section("Body content") {
          fadingChipScroller {
            ForEach(BodyPreset.allCases) { preset in
              optionChip(
                preset.rawValue,
                systemImage: preset.systemImage,
                isSelected: bodyPreset == preset,
                isEnabled: bodyPresetIsAvailable(preset)
              ) {
                bodyPreset = preset
                rebuildBody()
              }
            }
          }

          Toggle("Include recording date and time", isOn: $includesBodyTimestamp)
            .onChange(of: includesBodyTimestamp) {
              rebuildBody()
            }

          Toggle("Attach transcript as .txt", isOn: $attachesTranscript)
            .disabled(cleanedTranscript.isEmpty)
        }

        Section("AI polish") {
          Picker("Style", selection: $polishStyle) {
            ForEach(PolishStyle.allCases) { style in
              Text(style.rawValue).tag(style)
            }
          }
          .pickerStyle(.menu)

          if polishStyle == .custom {
            TextField("Tell AI how to rewrite it", text: $customInstructions, axis: .vertical)
              .lineLimit(2...4)
          }

          Button {
            Task {
              isPolishing = true
              defer { isPolishing = false }

              if let polished = await store.polishEmail(
                body: emailBody,
                instructions: polishInstructions
              ) {
                emailBody = polished
              }
            }
          } label: {
            HStack(spacing: 10) {
              if isPolishing {
                ProgressView()
                  .tint(.blue)
                Text("Cooking with \(store.defaultAIProvider.title)…")
              } else {
                Image(systemName: "sparkles")
                Text("Polish with \(store.defaultAIProvider.title)")
              }
            }
            .foregroundStyle(.blue)
          }
          .disabled(
            emailBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || isPolishing
          )
        }

        Section("Body") {
          TextEditor(text: $emailBody)
            .frame(minHeight: 220)
        }
      }
      .navigationTitle("Email Memo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Compose", systemImage: "envelope") {
            composeEmail()
          }
          .disabled(emailBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear {
        recipient = defaultRecipient
        if !cleanedPrefix.isEmpty {
          selectedSubjectParts.insert(.prefix)
        }
        includesBodyTimestamp = store.includeTimestampInExports
        rebuildSubject()
        chooseInitialBodyPreset()
        rebuildBody()
      }
      .sheet(item: $draft) { email in
        MailComposerView(draft: email) {
          draft = nil
          dismiss()
        }
      }
      .alert("Voxora", isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { if !$0 { store.errorMessage = nil } }
      )) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(store.errorMessage ?? "")
      }
    }
  }

  private var polishInstructions: String {
    polishStyle == .custom ? customInstructions : polishStyle.instructions
  }

  private var defaultRecipient: String {
    store.defaultEmailRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var cleanedPrefix: String {
    store.emailSubjectPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var cleanedTranscript: String {
    note.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var outputs: [GeneratedOutput] {
    store.outputs(for: note)
  }

  private var timestampText: String {
    note.timestamp.formatted(date: .long, time: .shortened)
  }

  private var transcriptAttachment: EmailAttachment? {
    guard attachesTranscript, !cleanedTranscript.isEmpty,
          let data = cleanedTranscript.data(using: .utf8) else {
      return nil
    }
    return EmailAttachment(
      data: data,
      mimeType: "text/plain",
      fileName: "\(safeFileName)-transcript.txt"
    )
  }

  private var safeFileName: String {
    let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let cleaned = note.displayTitle
      .components(separatedBy: invalidCharacters)
      .joined(separator: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "Voxora-Memo" : cleaned
  }

  @ViewBuilder
  private func addressField(_ label: String, text: Binding<String>) -> some View {
    TextField(label, text: text)
      .textContentType(.emailAddress)
      .textInputAutocapitalization(.never)
      .keyboardType(.emailAddress)
  }

  private func fadingChipScroller<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        content()
      }
      .padding(.vertical, 2)
      .padding(.horizontal, 4)
    }
    .contentMargins(.horizontal, 8, for: .scrollContent)
    .mask {
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: 0.035),
          .init(color: .black, location: 0.965),
          .init(color: .clear, location: 1)
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
    }
  }

  private func optionChip(
    _ title: String,
    systemImage: String,
    isSelected: Bool,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
          isSelected ? Color.accentColor : Color.secondary.opacity(0.14),
          in: Capsule()
        )
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.4)
  }

  private func subjectPartIsAvailable(_ part: SubjectPart) -> Bool {
    switch part {
    case .prefix:
      !cleanedPrefix.isEmpty
    case .tags:
      !store.tags(for: note).isEmpty
    case .date, .time, .source:
      true
    }
  }

  private func bodyPresetIsAvailable(_ preset: BodyPreset) -> Bool {
    switch preset {
    case .transcript:
      !cleanedTranscript.isEmpty
    case .latestOutput, .allOutputs:
      !outputs.isEmpty
    case .transcriptAndLatest:
      !cleanedTranscript.isEmpty || !outputs.isEmpty
    }
  }

  private func toggleSubjectPart(_ part: SubjectPart) {
    if selectedSubjectParts.contains(part) {
      selectedSubjectParts.remove(part)
    } else {
      selectedSubjectParts.insert(part)
    }
    rebuildSubject()
  }

  private func rebuildSubject() {
    let baseTitle: String
    if selectedSubjectParts.contains(.prefix), !cleanedPrefix.isEmpty {
      baseTitle = "\(cleanedPrefix) \(note.displayTitle)"
    } else {
      baseTitle = note.displayTitle
    }
    var parts = [baseTitle]

    if selectedSubjectParts.contains(.date) {
      parts.append(note.timestamp.formatted(date: .abbreviated, time: .omitted))
    }
    if selectedSubjectParts.contains(.time) {
      parts.append(note.timestamp.formatted(date: .omitted, time: .shortened))
    }
    if selectedSubjectParts.contains(.source) {
      parts.append(note.source.title)
    }
    if selectedSubjectParts.contains(.tags) {
      parts.append(store.tags(for: note).map(\.name).joined(separator: ", "))
    }

    subject = parts
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: " · ")
  }

  private func chooseInitialBodyPreset() {
    if !cleanedTranscript.isEmpty, !outputs.isEmpty {
      bodyPreset = .transcriptAndLatest
    } else if !cleanedTranscript.isEmpty {
      bodyPreset = .transcript
    } else if !outputs.isEmpty {
      bodyPreset = .latestOutput
    }
  }

  private func rebuildBody() {
    var sections: [String] = []
    if includesBodyTimestamp {
      sections.append(timestampText)
    }

    switch bodyPreset {
    case .transcript:
      sections.append(cleanedTranscript)
    case .latestOutput:
      sections.append(outputs.first?.content ?? "")
    case .transcriptAndLatest:
      sections.append(cleanedTranscript)
      sections.append(outputs.first?.content ?? "")
    case .allOutputs:
      sections.append(contentsOf: outputs.map {
        "\($0.actionTitle)\n\($0.content)"
      })
    }

    emailBody = sections
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: "\n\n")
  }

  private func composeEmail() {
    guard MFMailComposeViewController.canSendMail() else {
      store.errorMessage = VoxoraAPIError.mailUnavailable.localizedDescription
      return
    }

    draft = EmailDraft(
      recipients: parsedAddresses(recipient),
      ccRecipients: parsedAddresses(cc),
      bccRecipients: parsedAddresses(bcc),
      subject: subject,
      body: emailBody,
      attachments: [transcriptAttachment].compactMap { $0 }
    )
  }

  private func parsedAddresses(_ value: String) -> [String] {
    value
      .components(separatedBy: CharacterSet(charactersIn: ",;"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
