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

  @Bindable var store: VoxoraStore
  var note: AudioNote

  @Environment(\.dismiss) private var dismiss
  @State private var recipient = ""
  @State private var cc = ""
  @State private var subject = ""
  @State private var polishStyle: PolishStyle = .concise
  @State private var customInstructions = ""
  @State private var emailBody = ""
  @State private var draft: EmailDraft?
  @State private var isPolishing = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Email") {
          TextField("To", text: $recipient)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

          TextField("Cc (optional)", text: $cc)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

          TextField("Subject", text: $subject)
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
        recipient = store.defaultEmailRecipient
        subject = note.displayTitle
        emailBody = [note.transcriptText, note.transformedOutputText]
          .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
          .joined(separator: "\n\n")
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

  private func composeEmail() {
    guard MFMailComposeViewController.canSendMail() else {
      store.errorMessage = VoxoraAPIError.mailUnavailable.localizedDescription
      return
    }

    draft = EmailDraft(
      recipients: parsedAddresses(recipient),
      ccRecipients: parsedAddresses(cc),
      subject: subject,
      body: emailBody
    )
  }

  private func parsedAddresses(_ value: String) -> [String] {
    value
      .components(separatedBy: CharacterSet(charactersIn: ",;"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
