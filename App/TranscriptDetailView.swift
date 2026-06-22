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
  @State private var editingAction: PromptTemplate?
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
          VoxoraTheme.detailGradientTop,
          VoxoraTheme.detailGradientMiddle,
          VoxoraTheme.detailGradientBottom
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
    .sheet(item: $editingAction) { action in
      NavigationStack {
        ScrollView {
          PromptTemplateEditorCard(
            prompt: action,
            defaultProvider: store.defaultAIProvider,
            onDelete: {
              editingAction = nil
              store.deleteAction(action)
            }
          )
          .padding(20)
        }
        .navigationTitle("New AI Action")
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
          ForEach(orderedActions) { action in
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

          Button {
            editingAction = store.addAction()
          } label: {
            Label("Add", systemImage: "plus")
              .font(.subheadline.weight(.semibold))
              .padding(.horizontal, 14)
              .padding(.vertical, 11)
              .fixedSize()
          }
          .buttonStyle(.glass)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 4)
      }
      .scrollIndicators(.hidden)
      .mask {
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.18), location: 0.018),
            .init(color: .black.opacity(0.5), location: 0.04),
            .init(color: .black, location: 0.075),
            .init(color: .black, location: 0.925),
            .init(color: .black.opacity(0.5), location: 0.96),
            .init(color: .black.opacity(0.18), location: 0.982),
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
                Button(role: .destructive) {
                  store.deleteOutput(output)
                } label: {
                  Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(.leading, 6)
                }
                .buttonStyle(.plain)
              }
              StructuredOutputView(
                content: output.content,
                kind: outputKind(for: output)
              )
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

  private var orderedActions: [PromptTemplate] {
    let starterOrder: [UUID: Int] = [
      PromptKind.custom.starterID: 0,
      PromptKind.todo.starterID: 1,
      PromptKind.bullets.starterID: 2,
      PromptKind.numbered.starterID: 3
    ]
    return store.prompts
      .filter(\.isEnabled)
      .sorted {
        let left = starterOrder[$0.id] ?? 4 + $0.sortOrder
        let right = starterOrder[$1.id] ?? 4 + $1.sortOrder
        if left == right {
          return $0.createdAt < $1.createdAt
        }
        return left < right
      }
  }

  private func outputKind(for output: GeneratedOutput) -> PromptKind? {
    if output.actionID == PromptKind.todo.starterID { return .todo }
    if output.actionID == PromptKind.bullets.starterID { return .bullets }
    if output.actionID == PromptKind.numbered.starterID { return .numbered }
    return store.prompts.first(where: { $0.id == output.actionID })?.kind
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

}

private struct StructuredOutputView: View {
  let content: String
  let kind: PromptKind?

  var body: some View {
    switch kind {
    case .todo:
      list(items: parsedItems, style: .checklist)
    case .bullets:
      list(items: parsedItems, style: .bullets)
    case .numbered:
      list(items: parsedItems, style: .numbered)
    default:
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
          Text(inlineMarkdown(paragraph))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private enum ListStyle {
    case checklist
    case bullets
    case numbered
  }

  private func list(items: [String], style: ListStyle) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          marker(for: style, index: index)
            .frame(width: style == .numbered ? 24 : 18, alignment: .trailing)
          Text(item)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  @ViewBuilder
  private func marker(for style: ListStyle, index: Int) -> some View {
    switch style {
    case .checklist:
      Image(systemName: "square")
        .foregroundStyle(.secondary)
    case .bullets:
      Text("•")
        .font(.body.weight(.bold))
        .foregroundStyle(.secondary)
    case .numbered:
      Text("\(index + 1).")
        .font(.subheadline.monospacedDigit().weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }

  private var parsedItems: [String] {
    let headings = [
      "Actionable Checklist",
      "To Do",
      "To-Do",
      "Bulleted List",
      "Bullet List",
      "Numbered List"
    ]
    var source = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if let heading = headings.first(where: {
      source.lowercased().hasPrefix($0.lowercased())
    }) {
      source.removeFirst(heading.count)
      source = source.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    let lines = source
      .components(separatedBy: .newlines)
      .map(cleanedListItem)
      .filter { !$0.isEmpty }
    if lines.count > 1 {
      return lines
    }

    let sentencePattern = #"(?<=[.!?])\s*(?=[A-Z0-9])"#
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    let separated = (try? NSRegularExpression(pattern: sentencePattern))?
      .stringByReplacingMatches(in: source, range: range, withTemplate: "\n") ?? source
    let sentences = separated
      .components(separatedBy: .newlines)
      .map(cleanedListItem)
      .filter { !$0.isEmpty }
    return sentences.isEmpty ? [source] : sentences
  }

  private func cleanedListItem(_ source: String) -> String {
    var item = source.trimmingCharacters(in: .whitespacesAndNewlines)
    let patterns = [
      #"^[-*•]\s*\[[ xX]\]\s*"#,
      #"^[-*•]\s+"#,
      #"^\d+[\.)]\s+"#
    ]
    for pattern in patterns {
      guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
      let range = NSRange(item.startIndex..<item.endIndex, in: item)
      item = expression.stringByReplacingMatches(
        in: item,
        range: range,
        withTemplate: ""
      )
    }
    return item.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Splits the output into display lines. The model often separates sections
  /// with single newlines (which markdown would otherwise collapse into one
  /// wall of text), and sometimes runs bold "**Header:**" sections together —
  /// we break before an inline bold header so each lands on its own line.
  private var paragraphs: [String] {
    let withBreaks = content.replacingOccurrences(
      of: #"(?<=\S)\s*(\*\*[^*\n]+:\*\*)"#,
      with: "\n$1",
      options: .regularExpression
    )
    return withBreaks
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  private func inlineMarkdown(_ line: String) -> AttributedString {
    (try? AttributedString(
      markdown: line,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(line)
  }
}
