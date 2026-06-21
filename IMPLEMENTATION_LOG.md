# Voxora Implementation Log

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
