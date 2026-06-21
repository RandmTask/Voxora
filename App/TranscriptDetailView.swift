import SwiftUI
import UIKit

struct TranscriptDetailView: View {
  private enum DetailSection: String, CaseIterable, Identifiable {
    case transcript = "Transcript"
    case summary = "Summary"

    var id: String { rawValue }
  }

  @Bindable var store: VoxoraStore
  @Bindable var note: AudioNote
  @State private var isEditing = false
  @State private var isEmailing = false
  @State private var titleDraft = ""
  @State private var selectedSection: DetailSection = .transcript
  @FocusState private var isEditingTitle: Bool

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        titleBlock
        sectionPicker
        if selectedSection == .transcript {
          transcriptBlock
        } else {
          actionBlock
          outputBlock
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
    }
    .background(
      LinearGradient(
        colors: [
          Color(red: 0.04, green: 0.08, blue: 0.16),
          Color(red: 0.12, green: 0.28, blue: 0.43),
          Color(red: 0.84, green: 0.92, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
    .navigationTitle("Voice Memo")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit", systemImage: "pencil") {
            isEditing = true
          }

          Button("Copy", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = shareText
          }

          ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
          }

          Button("Email Memo", systemImage: "envelope") {
            isEmailing = true
          }
        } label: {
          Label("Note Actions", systemImage: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $isEditing) {
      NoteEditorSheet(store: store, note: note)
    }
    .sheet(isPresented: $isEmailing) {
      EmailWorkflowSheet(store: store, note: note)
    }
    .onAppear {
      titleDraft = note.title
    }
    .onChange(of: isEditingTitle) { _, isFocused in
      if !isFocused {
        saveTitle()
      }
    }
  }

  private var titleBlock: some View {
    GlassEffectContainer(spacing: 16) {
      VStack(alignment: .leading, spacing: 12) {
        TextField("Note title", text: $titleDraft, axis: .vertical)
          .font(.title2.weight(.bold))
          .lineLimit(1...3)
          .fixedSize(horizontal: false, vertical: true)
          .focused($isEditingTitle)
          .submitLabel(.done)
          .onSubmit {
            saveTitle()
            isEditingTitle = false
          }

        Label {
          Text("\(note.timestamp.formatted(date: .abbreviated, time: .shortened)) (\(formattedDuration))")
        } icon: {
          Image(systemName: "calendar")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(20)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private var sectionPicker: some View {
    Picker("Voice memo section", selection: $selectedSection) {
      ForEach(DetailSection.allCases) { section in
        Text(section.rawValue).tag(section)
      }
    }
    .pickerStyle(.segmented)
  }

  private var transcriptBlock: some View {
    GlassEffectContainer(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Label("Raw Transcript", systemImage: "text.quote")
          .font(.headline)
        Text(note.transcriptText.isEmpty ? "Transcription will appear here after watch handoff finishes." : note.transcriptText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
          .contextMenu {
            Button("Copy Transcript", systemImage: "doc.on.doc") {
              UIPasteboard.general.string = note.transcriptText
            }
          }
      }
      .padding(20)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private var actionBlock: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("AI Actions")
        .font(.headline)
        .padding(.horizontal, 4)

      ScrollView(.horizontal) {
        HStack(spacing: 12) {
          ForEach(store.prompts.filter(\.isEnabled)) { action in
            Button {
              Task {
                await store.runAction(action, on: note)
              }
            } label: {
              Label(action.title, systemImage: action.iconName)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .fixedSize()
            }
            .buttonStyle(.glassProminent)
          }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
      }
      .scrollIndicators(.hidden)
      .contentMargins(.horizontal, 4, for: .scrollContent)
      .mask {
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.025),
            .init(color: .black, location: 0.975),
            .init(color: .clear, location: 1)
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      }
    }
  }

  private var outputBlock: some View {
    GlassEffectContainer(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Label("Output History", systemImage: "sparkles")
          .font(.headline)
        if store.outputs(for: note).isEmpty {
          Text("Run an action above to generate an output.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(store.outputs(for: note)) { output in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(output.actionTitle)
                  .font(.subheadline.weight(.semibold))
                Spacer()
                Text(output.createdAt.formatted(date: .abbreviated, time: .shortened))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Text(renderedMarkdown(output.content))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .contextMenu {
                  Button("Copy Output", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = output.content
                  }
                }
            }
            .padding(.vertical, 6)
            if output.id != store.outputs(for: note).last?.id {
              Divider()
            }
          }
        }
      }
      .padding(20)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
  }

  private var shareText: String {
    ([note.transcriptText] + store.outputs(for: note).map(\.content))
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: "\n\n")
  }

  private func saveTitle() {
    let cleaned = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned != note.title else { return }
    note.title = cleaned
    note.updatedAt = .now
    store.persistChanges()
  }

  private var formattedDuration: String {
    let seconds = max(0, Int(note.duration.rounded()))
    let minutes = seconds / 60
    let remainder = seconds % 60
    return minutes == 0 ? "\(remainder)s" : "\(minutes)m\(remainder)s"
  }

  private func renderedMarkdown(_ source: String) -> AttributedString {
    (try? AttributedString(
      markdown: source,
      options: .init(interpretedSyntax: .full)
    )) ?? AttributedString(source)
  }
}
