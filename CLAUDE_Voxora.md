# Project: Voxora (iOS + watchOS Voice Recording / Transcription App)

> App-specific guidance. This **overrides** `../CLAUDE.md` on conflict.
> Cross-app rules (questions, surgical edits, batch summary, CloudKit playbook,
> gestures/haptics/UI conventions) still apply — link, don't duplicate.

---

## #0 Rule — Read Context First

At the start of every session, before touching any code:

1. **Read `IMPLEMENTATION_LOG.md`** — dated changelog, recent work, what's in flight.
2. **Read this file** for rules and the product map.
3. **Read [`../_shared/cloudkit-swiftdata.md`](../_shared/cloudkit-swiftdata.md)** before
   any schema/sync change — Voxora is a live CloudKit + SwiftData app.

---

## What Voxora is

A voice recording + transcription app in the vein of **Whisper Memos**, **Just Press
Record**, and **Stardate**. Record on iPhone or Apple Watch, get an automatic
transcript, then run reusable AI actions over it (summaries, lists, to-dos, custom
prompts) and ship the result somewhere useful (email, copy, share, and — in later
phases — Reminders, Calendar, export bundles).

**Targets / minimums:** iOS 26.0, watchOS 26.0 (see `Project.json`). Use current
SwiftUI; don't reintroduce older-OS shims.

**Surfaces:** iPhone app, Apple Watch app, iOS WidgetKit extension, Watch
complications. The Watch records chunks and transfers them to the phone over
`WatchConnectivity`; the phone owns transcription and AI processing.

---

## Architecture map (where things live)

| Concern | Files |
|---|---|
| App entry / model container | `App/VoxoraApp.swift`, `App/VoxoraPersistence.swift` |
| Store / app state | `App/VoxoraStore.swift` (UserDefaults-backed prefs), `Shared/AppPreferences.swift` |
| Home / list / detail | `App/VoxoraHomeView.swift`, `App/AudioNoteCard.swift`, `App/TranscriptDetailView.swift` |
| Search & filters | `App/TranscriptSearchView.swift` |
| Recording (phone) | `App/PhoneAudioRecorder.swift`, `Shared/RecordingState.swift` |
| Transcription | `App/SpeechTranscriber.swift` (Apple), `App/CloudAudioTranscriber.swift` (Gemini/OpenAI), `Shared/TranscriptionEngine.swift` |
| AI processing | `App/AIProcessingCoordinator.swift` + per-provider clients (`AnthropicClient`, `OpenAIClient`, `GeminiClient`, `DeepSeekClient`, `AppleIntelligenceClient`) |
| Prompts / actions | `Shared/PromptTemplate.swift`, `Shared/PromptKind.swift`, `App/PromptTemplateEditorCard.swift` |
| Automations | `Shared/AutomationProfile.swift`, `App/AutomationProfileEditorCard.swift` |
| Email workflow | `App/EmailWorkflowSheet.swift`, `App/EmailDraft.swift`, `App/MailComposerView.swift` |
| Share / actions sheet | `App/NoteActionsSheet.swift` |
| Tags | `Shared/NoteTag.swift`, `Shared/NoteTagAssignment.swift` |
| Watch ↔ Phone | `App/PhoneWatchConnectivityCoordinator.swift`, `Watch/*`, `Shared/TransferMetadata.swift`, `Shared/WatchRecordingSnapshot.swift` |
| Secrets | `App/KeychainStore.swift`, `Shared/AIProvider.swift` (`keychainKey`) |
| Widgets / deep links | `Widget Extension/*`, `iPhone Widget Extension/*`, `Shared/DeepLinkRoute.swift` |

---

## Data model (current `@Model` rows)

Schema is registered in `Shared/VoxoraSchema.swift`:

`AudioNote`, `PromptTemplate`, `NoteTag`, `NoteTagAssignment`, `GeneratedOutput`,
`AutomationProfile`, `DeletedAudioNote`.

Key shapes:
- **`AudioNote`** — one recording: `transcriptText`, `transformedOutputText`,
  `processingStatusRawValue`, `isFavorite`, `archivedAt`, `audioFileName`,
  `duration`, `source`. `maximumTooShortDuration = 3s` (too-short outranks failed).
- **`PromptTemplate`** — a reusable AI action: `kind` (`todo`/`numbered`/`bullets`/
  `custom`), `promptBody`, `iconName`, `providerOverride`, `sortOrder`, `isEnabled`.
  Starter prompts have **fixed `starterID` UUIDs** (`PromptKind.starterID`) — don't
  reassign them.
- **`AutomationProfile`** — run action `actionID` automatically for a `RecordingSource`,
  optionally `generateTitle`.
- **`GeneratedOutput`** — history of one action's output, keyed by `noteID` + `actionID`.
- **`DeletedAudioNote`** — tombstone. See tombstone rule below.

---

## #1 Rule — Never Lose User Data

This overrides speed, cleanliness, and feature completeness. Voxora syncs via
CloudKit (`iCloud.com.swiftstudio.Voxora`, `cloudKitDatabase: .automatic`), so the
[`../_shared/cloudkit-swiftdata.md`](../_shared/cloudkit-swiftdata.md) non-negotiables
are binding. In brief, app-specific:

| Situation | Rule |
|---|---|
| New `@Model` property | Always a default value (the existing models all do this — match it). No `@Attribute(.unique)`. |
| Removing/renaming a field | Don't remove from a shipping schema; add-and-migrate. |
| Audio files | Audio lives on disk via the app-group container (`Shared/AudioFileStore.swift`), referenced by `audioFileName`. If audio ever becomes a CloudKit field, use `@Attribute(.externalStorage)` — never inline a >1 MB blob. |
| Deletes | `DeletedAudioNote` is a **synced tombstone**, not history. The load path must suppress any note whose `id` appears in a tombstone, or deleted notes resurrect from a stale device. Tombstones survive "clear history." |
| Delete-from-absence | Never delete a row because it's missing from a stale in-memory array. Writes are intent-based; delete only via explicit tombstone. |
| Saves | `try? save()` only for leaf toggles (favorite, reorder). Creates / transcript / output writes use `do/catch` and log. |
| Write only changed rows | One AI run writes that note + its `GeneratedOutput`; don't re-save unrelated rows (CloudKit last-writer-wins will revert them). |

**Schema-change flag:** any add/remove/rename of an `@Model` field requires a
**CloudKit Dev→Prod redeploy before the next TestFlight build** — call it out
explicitly in the batch summary (item 4).

---

## #2 Rule — API keys must be proxied before release (non-negotiable)

Provider keys (`AIProvider.keychainKey`, e.g. `provider.openAI.apiKey`) currently
live in the **device Keychain** (`App/KeychainStore.swift`) — never CloudKit, never
UserDefaults, never the synced store, never the binary. The automation editor already
shows the RED dev-only warning (`AutomationProfileEditorCard.swift:38`).

**Before any TestFlight/public release**, all AI + cloud-transcription calls
(`AIProcessingCoordinator`, `CloudAudioTranscriber`, every provider client) must route
through a backend proxy (Supabase Edge Function / Cloudflare Worker) that holds keys
server-side, with (1) per-user/day rate limits, (2) a hard monthly spend cap /
kill-switch, (3) auth scoped to the owner. Apple Speech / Apple Intelligence are
on-device and exempt. Keep the RED warning anywhere a raw key is entered until the
proxy ships.

---

## Providers

- **AI actions:** `AIProvider` = Apple Intelligence (on-device, blue, no key),
  Gemini, DeepSeek, OpenAI, Claude(Anthropic). Each `PromptTemplate` may override the
  global provider.
- **Transcription:** `TranscriptionEngine` = Apple Speech (on-device), Gemini, OpenAI.
- When building anything that calls Claude/Anthropic, consult the `claude-api` skill
  and default to the latest model (Opus 4.8 for quality, Haiku 4.5 for cheap/fast).

---

## Product roadmap

### ✅ / 🟡 Phase 1 — Low-hanging fruit (mostly built)
- **Email workflow** — `EmailWorkflowSheet` + `EmailDraft` + `MailComposerView`:
  subject prefix/date/time/source/tags chips, body presets, optional transcript
  attachment, recipient/Cc/Bcc. No schema change.
- **Copy & system Share Sheet** — transcript / output / both via `NoteActionsSheet`.
- **Editable transcript & output** — `NoteEditorSheet` / detail editing before
  generating or emailing.
- **Search & filters** — `TranscriptSearchView`; filter active/archived/failed/
  processing, persisted via `AppStorage`. ("Hide unusable" = too-short + empty.)

### 🟡 Phase 2 — Organization & automation (partly built)
- **Titles, favorites, richer tags** — AI-or-manual titles, `isFavorite` pinning,
  `NoteTag`/`NoteTagAssignment`. *(Schema already present — confirm Dev→Prod deployed.)*
- **Custom reusable AI actions** — `PromptTemplate` rows beyond the fixed starters:
  add/reorder (`sortOrder`), icon picker, per-action provider. Built; extend as needed.
- **Automatic processing profiles** — `AutomationProfile`: auto-run an action by
  `RecordingSource` after transcription, optional auto-title.

### 🔭 Phase 3 — Workflow integrations (not yet built — next big arc)
- **Apple Reminders from action items** — parse the to-do action's output, show an
  editable preview list, explicit confirm before `EKReminder` creation. Needs
  Reminders entitlement + `NSRemindersFullAccessUsageDescription`. Confirmation
  screen is mandatory (no silent writes to the user's lists).
- **Calendar events from spoken dates** — detect meetings/deadlines (date/time NER
  via the AI action or `NSDataDetector`), confirmation screen, then `EKEvent`. Needs
  Calendar entitlement + usage string. Map relative dates against the **recording's**
  timestamp, not "now."
- **Export & backup bundles** — export selected notes as `.txt`/Markdown + original
  audio + generated outputs into a zipped bundle via share sheet / Files.

### 💡 Proposed next-phase features (pitch to Deon before building)
Surface these in batch-summary "next step" questions; don't build unprompted.

**Audio input**
- **Import audio files (approved)** — `.fileImporter` / `UIDocumentPickerViewController` accepting
  `UTType.audio` (MP3, M4A, WAV, etc.). Copy into AudioFileStore, create `AudioNote`, route
  through the same transcription pipeline. Apple Speech handles M4A; Gemini/OpenAI handle MP3.
  Needs `NSMicrophoneUsageDescription` already present; no new entitlement.
- **Audio trimming / re-record** before transcription.
- **Live transcription while recording** — stream partials on iPhone.
- **Watch standalone transcription** when the phone is unreachable (deferred today).

**Organisation (approved direction: tag-based, not folders)**
- **Tag system like SteadyState** — tag pills in list header, tap to filter, multi-tag per note
  already supported via `NoteTagAssignment`. Build a horizontal pill strip filter above the list.
  No schema change needed.
- **Saved searches** — persist a search query + active filters as a named shortcut.
- **Bulk / multi-select** — select multiple notes to: delete with confirm, archive, assign tags,
  export as bundle, or email combined. Needs a multi-select mode toggle in the list toolbar.
- **Recording presets** (Meeting / Memo / Idea) bundling source + action + tags.

**Automation & workflows**
- **Auto-email** — after transcription, if note duration ≥ user-set threshold, post a local
  notification deep-linking to the email compose sheet (iOS Mail requires foreground; cannot
  send silently). Complexity: medium. Settings: toggle on/off + minimum seconds.
- **Shortcuts / App Intents** — "Record a Voxora memo", "Summarise last memo", "Email last memo".
- **Apple Reminders from action items** — parse to-do output → preview list → confirm → `EKReminder`.
  Needs Reminders entitlement + `NSRemindersFullAccessUsageDescription`.
- **Calendar events from spoken dates** — NER via AI or `NSDataDetector` → confirmation → `EKEvent`.
  Map relative dates against the recording's timestamp, not "now."

**Whisper / on-device transcription**
- **Download and cache Whisper models** — use `WhisperKit` or similar. Key risk: iOS will silently
  evict files in `Caches/` when storage is low; models must live in `Application Support/` (not
  Caches) so they survive low-storage purges. Show a "model missing — re-download?" prompt rather
  than silently failing. This is the same bug that affected Just Press Record. Never assume a model
  file is present without `FileManager.default.fileExists` check at call time.

**Haptics**
- **iPhone haptics** — `UIFeedbackGenerator` (light impact on record start, heavy on stop,
  success notification on transcription complete, error on failure). See `../_shared/haptics.md`.
- **Apple Watch haptics** — `WKHapticType` in the Watch target: `.start` on record, `.stop` on
  stop, `.success` on transfer complete.

**AI & output**
- **Speaker / chapter segmentation** — timestamped sections; tap to seek.
- **Tappable transcript ↔ audio sync** — highlight word at playhead.
- **Smart auto-tagging** — AI suggests tags on import; user accepts.
- **Per-note default action / "favorite action"** — one-tap re-run.
- **Search inside generated outputs** and across `GeneratedOutput` history.
- **Transcription language picker** + per-note detected language.

**Export & backup**
- **Export & backup bundles** — selected notes as `.txt`/Markdown + audio + generated outputs,
  zipped via share sheet / Files app.
- **iCloud-safe full backup/restore** (`.voxora` bundle) for migration.

**Advanced**
- **Widget: latest memo summary** (not just Quick Record).
- **iCloud-safe full backup/restore**.
- **Folders vs tags decision**: tag-based filtering is the approved direction; true folders
  require a schema change and are lower priority.

When scoping any of these, run the cross-app pre-code checklist:
[`../_shared/questions-to-ask.md`](../_shared/questions-to-ask.md), and ask ≥10
numbered questions with recommendations before writing code.

---

## How to build & test (required before reporting done)

- **Build** for the **iPhone 17 Pro, iOS 26.5 simulator** scheme `Voxora` (builds
  Watch + both widget extensions as dependents) before calling a coding task done.
- Project is xcodegen-style (`Project.json`); if you add files, regenerate the Xcode
  project rather than hand-editing `project.pbxproj` where possible.
- **Always give concrete test steps** (`action → expected`), one per observable change.
- **Data-integrity repro:** record → transcribe → run action → navigate away → back →
  confirm transcript, output, title, favorite, and tags persist. After any schema
  change, delete + reinstall to confirm clean migration.
- **List removal** (archive/delete/un-archive): verify no "text over text" overlap —
  use a collapsing removal transition or real `List`/`.onDelete`
  (see `../CLAUDE.md` UI interaction defaults).

---

## End-of-batch summary

Always close with the cross-app structured summary from `../CLAUDE.md`:
Changes table → How to test → What was learned/_shared updated → **Schema changes
(CloudKit redeploy?)** → Next-step question → Model used → Terminology corrections.

## Model usage
Haiku/Sonnet for repo search, mechanical audits, layout passes, doc/log writing.
Opus for architecture, CloudKit/data-safety, concurrency, Watch sync, final review.
State which model did what in the summary.
