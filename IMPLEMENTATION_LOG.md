# Voxora Implementation Log

## 2026-06-21 — Compact settings navigation and Voice Memo presentation

- Moved note status indicators to the true trailing edge of the title row.
  Status replaces the disclosure chevron when present; idle rows retain the
  centered chevron.
- Replaced the long inline Settings editor with a compact landing page:
  - Email, AI Model, AI Actions, Automations, and Tags now have dedicated screens.
  - Individual AI actions and automations open in editor sheets.
  - Email recipient and subject-prefix controls now live in Email Settings.
- Replaced raw SF Symbol names in action lists/editors with rendered symbols and a
  curated symbol menu.
- Simplified action provider presentation to `Provider: Apple Intelligence` style
  naming and added provider color treatments; Apple Intelligence is blue.
- Made destructive trash icons and labels consistently red.
- Updated Voice Memo detail:
  - Editable titles can wrap across multiple lines.
  - AI actions are independent horizontally scrolling glass buttons.
  - Generated output is rendered as Markdown rather than shown as raw markup.
- Verified a successful full iPhone 17 Pro iOS 26.5 simulator build, including
  dependent Watch and widget targets.

### Schema changes

None.

### Next validation

On a physical iPhone, verify trailing status placement with long titles, action and
automation editor sheet presentation, destructive colors, and Markdown list/heading
rendering in Summary.

## 2026-06-21 — iPhone widgets and persistent note filters

- Added a separate iOS WidgetKit extension embedded in the iPhone app.
- Added Quick Record and Open Voxora widgets for small, medium, and Lock Screen
  accessory families.
  - Quick Record opens the Record tab and starts exactly one iPhone recording.
  - Open Voxora opens the Record tab without starting a recording.
  - Medium Quick Record provides separate Record and Open actions.
- Added a second Apple Watch complication that opens Voxora without starting or
  resuming a recording; the existing Quick Record complication remains unchanged.
- Added explicit deep-link consumption by the iPhone recording screen.
- Unified both iPhone widgets around one dark teal palette, consistent 34-point
  waveform artwork, explicit high-contrast text colors, and compact custom action
  capsules.
- Replaced the wrapping `Open App` widget action with the single-line label `Open`.
- Persisted note-list filters with `AppStorage`.
- Combined Hide too short and Hide empty into one Hide unusable filter.
- Regenerated the Xcode project and verified a successful full build for the
  iPhone 17 Pro iOS 26.5 simulator and dependent watchOS targets.

### Schema changes

None. Widget configuration is target-local and filter choices use local
`UserDefaults`.

### Next validation

On a physical iPhone, add both Voxora widgets and verify Quick Record starts once,
Open does not start recording, the medium actions remain single-line, and filter
choices survive an app relaunch.

## 2026-06-21 — Note status alignment, duration labels, and deferred Watch transcription

- Moved each note status into the title row with first-baseline alignment so Ready,
  Failed, Too short, and in-progress indicators stay on the same plane as the title.
- Removed the `Long-press for actions` footer and moved compact durations beside
  the date using forms such as `32s` and `1m42s`.
- Centralized the too-short rule as three seconds or less.
  - Too short takes display and filtering priority over Failed.
  - Existing short notes are normalized on startup.
  - Retranscription is unavailable for recordings at or below the threshold.
- Added a segmented Transcript/Summary control at the top of Voice Memo detail.
  Transcript contains the raw transcript; Summary contains AI actions and output
  history.
- Hardened Watch imports received while the iPhone app is not active:
  - The transferred file remains in Uploading instead of starting Apple Speech in
    the background.
  - Pending imports resume automatically when the iPhone app becomes active.
  - Empty/missing staged files are detected before recognition.
  - Apple Speech gets one short retry for transient startup failures.
  - A background interruption returns the note to Uploading instead of Failed.
- Verified a successful full build for the iPhone 17 Pro iOS 26.5 simulator and its
  dependent watchOS targets.

### Schema changes

None.

### Next validation

On physical devices, finish a Watch recording while Voxora is closed on iPhone,
then open Voxora and confirm the note moves from Uploading to Ready without briefly
showing Failed. Also verify title/status alignment with long titles and both detail
segments.

## 2026-06-21 — Note-list gestures, search focus, and Voice Memo polish

- Moved Copy Transcript out of swipe actions and added both Copy Transcript and
  Email Memo to the note-row long-press menu.
- Reduced the trailing swipe set to Delete, Generate, and Favorite; note rows should
  not expose four swipe actions unless a future product decision explicitly calls
  for it.
- Reworked note-card trailing presentation:
  - The disclosure chevron is vertically centered.
  - Ready, failed, too-short, empty, and in-progress icons share one position.
  - Non-ready status text sits immediately to the left of its icon.
- Replaced the position-sensitive delete confirmation dialog with a standard alert
  containing an explicit destructive Delete Note action.
- Promoted AI Actions to a section heading and applied fading horizontal edges to
  the independently scrolling action buttons.
- Renamed transcript detail to Voice Memo and removed Share Timestamp from that
  screen and from its Copy/Share payload.
- Adopted the iOS 26 search tab role and bound search presentation so selecting
  Search again focuses the field.
- Added immediate keyboard dismissal when scrolling or tapping the search-results
  list.
- Verified a successful full build for the iPhone 17 Pro iOS 26.5 simulator and its
  dependent watchOS targets.

### Schema changes

None.

### Next validation

On a physical iPhone, verify repeated Search-tab focus, context-menu Email Memo
presentation, delete-alert placement, and compact status alignment with long titles.
The requested pause-function change still needs a specific desired behavior.

## 2026-06-21 — Email Memo composition controls

- Added horizontally scrolling subject chips for the configured prefix, recording
  date, recording time, source device, and assigned tags.
- Added fading leading and trailing edges to the chip scrollers so clipped controls
  visually recede as they move offscreen.
- Added body presets for transcript only, latest AI output, both, and all AI outputs.
- Kept the email body editable after choosing a preset or applying AI polish.
- Added independent body timestamp and transcript `.txt` attachment controls.
- Added a recipient options menu for restoring the default recipient and revealing
  optional Cc and Bcc fields.
- Extended the native Mail handoff to include Bcc recipients and attachments.
- Regenerated the Xcode project and verified a successful full build for the iPhone
  17 Pro iOS 26.5 simulator and its dependent watchOS targets.

### Schema changes

None. The new controls are draft-local and reuse existing note, tag, output, and
local preference data.

### Next validation

On a physical iPhone, confirm chip fading and keyboard behavior, then send test
messages covering Cc/Bcc, each body preset, AI polish, and the transcript attachment.

## 2026-06-21 — Transcript, note-list, and email workflow UI pass

- Removed the duplicated row of large Edit, Copy, Share, and Email buttons from
  transcript detail; these secondary actions remain in the trailing toolbar menu.
- Replaced `NavigationLink` note rows with explicit button-driven navigation so the
  disclosure chevron can live inside each glass card.
- Simplified ready-state presentation to the green checkmark only, retaining an
  accessibility label without repeating the visible word “Ready.”
- Replaced the sticky `Recent notes` section header with an opaque in-flow list row
  so it no longer becomes translucent or overlaps note content while scrolling.
- Kept the filter icon outlined whether or not filters are active.
- Expanded the Email Memo workflow:
  - Added a persisted default recipient setting.
  - Added an optional Cc field and passed Cc recipients to the native Mail composer.
  - Added concise, friendly, formal, and action-focused polish presets.
  - Retained custom AI polish instructions.
  - Added a local blue progress treatment reading “Cooking with [provider]…” while
    polishing, rather than allowing the disabled state to wash the label white.
  - Moved Compose to the trailing navigation-bar action.
- Verified a successful full build for the iPhone 17 Pro iOS 26.5 simulator,
  including its paired watchOS targets.

### Schema changes

None. The default email recipient is stored in local `UserDefaults`.

### Reusable lessons

Added cross-app guidance to `_shared/ui-conventions.md` covering secondary-action
duplication, custom navigation-row chevrons, sticky list headers, async button state,
and icon-only status accessibility.

### Next validation

Run the note-list scroll, Email Memo polish, and native Mail handoff on a physical
iPhone to confirm keyboard behavior, Apple Intelligence progress timing, and the
configured default recipient/Cc values.

## 2026-06-21 — Voice-note interaction and transcript polish

- Added Copy Transcript to the note-row long-press menu and copy actions to
  transcript/output text.
- Moved the ready checkmark to the same trailing alignment as the disclosure
  chevron.
- Replaced the recording completion checkmark and large End & Transcribe button
  with a Voice Memos-style live audio meter and compact red stop control.
- Kept pause/resume visible only when the pause recording preference is enabled.
- Removed the destructive swipe role that caused note rows to disappear before
  delete confirmation.
- Added a configurable email subject prefix.
- Replaced vertically stacked AI actions with compact horizontally scrolling
  buttons and split the starter list action into Numbered List and Bulleted List.
- Added inline transcript-title editing and a Share Timestamp preference that
  includes the recording date/time in copied, shared, and emailed note content.
- Verified successful iPhone arm64 simulator and watchOS simulator builds.

### Schema changes

None. New settings use local preferences, and the new starter AI action uses the
existing `PromptTemplate` model.

### Next phase

Add synced custom transcription vocabulary/keywords for names and terms that are
commonly mistranscribed, then feed them into each supported transcription engine
where the engine API permits contextual vocabulary.

## 2026-06-21 — Phase 1 workflow tools and recording re-entry fix

- Added searchable voice notes with All, Active, Archived, and Failed filters.
- Added draft-based editing for transcript and generated output.
- Added copy and system share actions from transcript detail.
- Added the Email Memo workflow:
  - Optional recipient and editable subject.
  - Editable transcript/generated-output body.
  - Optional AI polishing through the selected provider.
  - Native Mail composer handoff.
- Fixed the Quick Record complication so reopening Voxora during an active recording
  does not start another recorder or audio chunk.
- Added a second duplicate-start guard inside `WatchAudioEngineManager`.
- Regenerated the Xcode project to include the new Swift files.
- Verified the iOS, watchOS, and complication targets with a successful simulator build.

### Schema changes

None.

### Next phase

Phase 2 organization and automation: note titles/favorites/tags, reusable AI actions,
and automatic processing profiles. This phase requires product decisions and likely
CloudKit schema changes before implementation.

## 2026-06-21 — Phase 2 organization and automation

- Added dedicated synced note organization fields:
  - AI-generated or editable titles with date-based fallback display.
  - Favorites sorted above other notes.
  - Dedicated archive date instead of overloading the legacy `tag` field.
  - Recording source tracking for iPhone and Apple Watch.
- Added first-class synced tag and note-tag-assignment rows.
  - Multiple tags per note.
  - Tag deletion removes assignments but never deletes notes.
- Replaced the fixed three-button prompt UI with reusable synced AI actions.
  - Editable title, prompt, SF Symbol, provider override, and enabled state.
  - Existing To-Do, Bullets, and Custom actions remain starter actions.
- Added first-class generated-output history rows so new results no longer overwrite
  the only saved output.
- Added opt-in synced automation profiles.
  - Match iPhone, Watch, or either recording source.
  - Run one selected action per profile after transcription.
  - Optionally generate a title.
- Added visible red development warnings anywhere a raw cloud-provider API key can
  power automatic processing.
- Added note deletion tombstones and suppression of resurrected note rows.
- Added legacy migration for archived notes, Watch source metadata, and the previous
  single generated output.
- Hardened CloudKit configuration:
  - Explicit portable `CloudKit.framework` linkage.
  - Both APS entitlement keys.
  - Ubiquity key-value-store entitlement.
  - Background processing mode and Core Data CloudKit task identifier.
- Regenerated the Xcode project.
- Verified a successful full simulator build and successful iPhone simulator launch.

### Schema changes

Added `AudioNote` organization/source fields and the following CloudKit-backed models:

- `NoteTag`
- `NoteTagAssignment`
- `GeneratedOutput`
- `AutomationProfile`
- `DeletedAudioNote`

CloudKit Development → Production schema deployment is required before the next
TestFlight build. Push Notifications and iCloud/CloudKit capabilities must also be
confirmed for the App ID in the Apple Developer portal.

### Next phase

Phase 3 integrations: confirmed Apple Reminders creation, confirmed Calendar event
creation, and export/backup bundles.

## 2026-06-21 — Recording reliability and navigation follow-up

- Fixed iPhone recordings being marked too short by capturing `AVAudioRecorder`
  duration before stopping the recorder.
- Fixed the recording-control settings by moving them from non-observable computed
  `UserDefaults` accessors to observable stored properties with persistence.
- Added the Watch audio background mode.
- Made Watch recording sessions recoverable across app-process relaunch:
  - Persist the active note id and session metadata.
  - Store chunks in the durable app-group audio directory.
  - Restore existing chunks after relaunch.
  - Resume the recovered session only when necessary; reopening a still-running
    recording remains a no-op.
- Added a standard SwiftUI `TabView`, which receives the native Liquid Glass tab bar
  on iOS 26.
- Added a dedicated Search tab with an always-visible transcript search field.
- Moved the note filter to the trailing toolbar and added independent exclusions for
  too-short, empty, and failed recordings.
- Added visible Edit, Copy, Share, and Email actions at the top of transcript detail.
- Reduced swipe-delete visual glitches by disabling full-swipe deletion and allowing
  the native swipe row to close before showing confirmation.
- Regenerated the Xcode project and verified a successful full simulator build.

### Schema changes

None in this follow-up batch.

### Next validation

Run the Watch background-continuity test on physical hardware. The simulator cannot
faithfully validate watchOS microphone recording or background audio execution.

## 2026-06-21 — Appearance modes

- Added Light, Dark, and System appearance choices in Settings.
- Made Dark the default for new installs while preserving the user's selection.
- Applied the selected color scheme once at the app root so tabs, sheets, and
  navigation destinations stay consistent.
- Applied the selection directly to the open Settings sheet so it changes
  appearance immediately without being dismissed and reopened.
- Replaced the hardcoded dark page and transcript-detail backgrounds with adaptive
  light/dark theme colors.

### Schema changes

None.
