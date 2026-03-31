# DXWhisp — Voice Notes with Transcription, Speaker Detection & AI Insights

## Operating Mode
- **Always think deeply** — trace data flow end-to-end, consider race conditions, edge cases
- **Ultrathink on**: architecture, concurrency, refactors touching >2 files, performance
- **Verify APIs** with `mcp__apple-docs__search_apple_docs` — never guess
- **Build + test after every change** — never assume code works
- **Staff mindset**: correctness > performance > style. Delete > add. Simple > clever.

## Critical Context (survives compaction)
- **TCA project** — NEVER `@Observable`, `ObservableObject`, `@Published` → use `@Reducer`, `@ObservableState`, `@Dependency`, `@Presents`
- NEVER modify `.pbxproj` directly — add files through Xcode
- Use XcodeBuildMCP for build/test/run — never raw xcodebuild
- xcargs: `-skipPackagePluginValidation -skipMacroValidation ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO`

## Build
- **Scheme**: DXWhisp | **Project**: DXWhisp.xcodeproj | **iOS 26+** | Swift 6.2
- **Bundle**: me.yasirromaya.whisp | **Team**: 9W4STM7DA3
- **Simulator**: iPhone 17 Pro | **SPM cache**: SPMCache/
- **Fastlane lanes**:
  - CI: `ci_test`, `ci_ui_test`, `ci_build`
  - Code Signing: `certificates`, `certificates_dev`, `certificates_refresh`
  - Build/Test: `build`, `test`
  - Screenshots: `screenshots`, `whisp_frame`, `screenshots_and_frame`
  - Distribution: `metadata`, `beta`, `release`
  - Versioning: `bump`

## Subscription (Freemium)
| Feature | Free | Pro |
|---------|------|-----|
| Recordings | 3/month | Unlimited |
| Transcription | Basic text only | + speaker detection |
| AI Insights | No | Yes |
| Auto-export | No | Reminders + Calendar |
| Tags | 3 max | Unlimited |
| Biometric lock | No | Yes |

- **StoreKit 2**: monthly ($6.99) + yearly ($49.99, "Save 40%")
- **AppFeature.isPro** = single source of truth, synced to children via `syncIsProToChildren()`
- **Cached**: `UserDefaults.isProCached` for instant UI on cold launch; verified async with StoreKit
- **Gates**: child features send `.delegate(.paywallRequested)` → AppFeature presents paywall sheet
- **Downgrade**: auto-disables `autoExportReminders` + `autoExportCalendar`

## Data Flow: Record → Transcribe → Save → Display
```
RecordButton tap → AudioRecorderClient.startRecording() → .m4a file
  + RecordingAnimationView (Lottie) plays during recording
  → RecordingFeature.delegate(.recordingCompleted(url, duration))
  → AppFeature.processRecording(url, duration)
    → TranscriptionClient.transcribe(url) → Transcription (text + segments + speakerTurns)
    → [Pro only] segments + speakerTurns preserved; free users get text-only
    → [Pro only] TranscriptionClient.extractInsights(text) → Insights
    → VoiceNote created (id, title, audioURL, duration, transcription, insights)
    → PersistenceClient.saveNote(note) → ~/Documents/Notes/{UUID}.json
    → [Pro only] Auto-export: actionItems → Reminders, events → Calendar
    → .transcriptionCompleted(note) → notesList.notes.insert(note)
    → currentNote = NoteDetailFeature.State(note:) → sheet opens
```

## Navigation: TabView + Sheet
```
RootView (onboarding gate: hasCompletedOnboarding?)
└── OnboardingView (multi-page flow, shown once)
└── AppView (TabView with 3 tabs)
    ├── Notes Tab → NotesListView (NavigationStack)
    │   ├── .sheet(item: currentNote) → NoteDetailView
    │   └── .sheet(item: tagEditor) → TagEditorView
    ├── Record Tab → RecordingView (NavigationStack)
    │   └── Lottie RecordingAnimationView during recording
    └── Settings Tab → SettingsView (NavigationStack)
        └── Subscription section + integration toggles
    + .sheet(item: paywall) → PaywallView (from any tab via delegate)
```
- Note detail: `@Presents var currentNote: NoteDetailFeature.State?` on AppFeature
- Open: `state.currentNote = NoteDetailFeature.State(note:)`
- Close: `state.currentNote = nil`

## State Ownership
- **AppFeature** owns: `tab`, `isPro`, `subscriptionStatus`, `error`, and scopes into child features
- **AppFeature** syncs `isPro` to all children via `syncIsProToChildren()` on subscription updates
- **AppFeature.notesList.notes** (`IdentifiedArrayOf<VoiceNote>`) — the single source of truth for all notes
- **NotesListFeature** owns: `filteredNotes` (memoized, recomputed via `recomputeFilteredNotes()`), `tags`, `selectedFilterTagIDs`, `selectedNoteIDs` (bulk ops), `isEditing`, `isPro` (synced)
- **NoteDetailFeature** gets a copy of one note via `@Presents` — communicates changes back via `.delegate(.noteUpdated(note))` and `.delegate(.noteDeleted(id))`
- **RecordingFeature** owns: `recordingState`, `currentDuration`, `postRecording`, `isPro` + `monthlyRecordingCount` (synced)
- **AppFeature** mutates `notesList.notes` on delegate receipt — never NoteDetail directly

## Feature Hierarchy
```
RootFeature
├── OnboardingFeature (multi-page intro, permission requests)
└── AppFeature (tabs + transcription orchestration + auto-export + subscription)
    ├── NotesListFeature (load, search, filter by tags, favorite, delete, bulk ops, lock)
    │   └── TagEditorFeature (@Presents — CRUD tags with colors)
    ├── RecordingFeature (permission, record, timer, stop, 3/month free limit)
    ├── NoteDetailFeature (@Presents — playback, speaker turns, export, delete, lock/unlock, biometric auth)
    ├── SettingsFeature (preferences, auto-export toggles, subscription status)
    └── SubscriptionFeature (@Presents — paywall with product cards, purchase, restore)
```
**Packages**: `DXWhispKit` (models + clients) | `DXWhispUI` (shared components)

## Clients (DXWhispKit — all @Dependency injected)
```swift
AudioRecorderClient:    requestPermission, prepareSession, startRecording, stopRecording → URL
AudioPlayerClient:      play(URL), pause, resume, seek(TimeInterval), currentTime, onPlaybackFinished → AsyncStream
TranscriptionClient:    transcribe(URL) → Transcription, extractInsights(String) → Insights,
                        requestSpeechAuthorization() → Bool
PersistenceClient:      saveNote, loadNotes, deleteNote, updateNote, saveTags, loadTags
EventKitClient:         requestRemindersAccess, addReminder, requestCalendarAccess, addCalendarEvent
BiometricClient:        authenticate() → Bool (Face ID / Touch ID / Optic ID)
HapticClient:           impact(FeedbackStyle), notification(FeedbackType), selection()
UserDefaultsClient:     getBool, setBool, optionalBool
SubscriptionClient:     checkStatus, loadProducts, purchase(String), restorePurchases, statusStream
```

## Models (DXWhispKit)
```swift
VoiceNote:            id, createdAt, title(var), audioFilename, duration, transcription?, insights?,
                      isFavorite(var), isLocked(var), tagIDs(var)
                      — audioURL computed from audioFilename (hardened path)
                      — Custom Decoder for backward compat (isLocked defaults false)
Tag:                  id, name, color (enum: 10 colors)
Transcription:        text, segments: [TranscriptionSegment], speakerTurns: [SpeakerTurn]
                      — Backward-compat decoder (segments/speakerTurns default [])
TranscriptionSegment: text, timestamp, duration, confidence
SpeakerTurn:          speakerLabel, text, startTime, endTime
Insights:             summary?, actionItems: [ActionItem], events: [ExtractedEvent], keyPoints: [String]
ActionItem:           id, text, isCompleted, exportedToReminders
ExtractedEvent:       id, title, date?, rawDateText, exportedToCalendar
RecordingState:       .idle | .recording(duration:) | .processing
SubscriptionStatus:   .unknown | .notSubscribed | .subscribed(productID, expirationDate?)
                      | .expired(...) | .inGracePeriod(...) | .inBillingRetry(...) | .revoked
                      — .isPro computed: true for .subscribed and .inGracePeriod
SubscriptionProduct:  id, displayName, description, displayPrice, price, period (.monthly/.yearly)
```

## Transcription Pipeline
- **Speech Recognition**: SFSpeechRecognizer — fast and accurate
- **Segment Extraction**: SFTranscriptionSegment → TranscriptionSegment (text, timestamp, duration, confidence)
- **Speaker Detection**: SpeakerDetector — pause-based heuristic:
  - Groups segments into utterances (gap < 1.2s)
  - Marks speaker changes at gaps > 3.0s
  - Up to 6 speakers, labeled "Speaker 1", "Speaker 2", etc.
- **Insight Extraction** (rule-based, all iOS versions):
  - Summary: NLTokenizer(.sentence), first 1-2 sentences
  - Action items: Pattern matching ("need to", "should", "must", "will [verb]", etc.)
  - Events: NSDataDetector(.date) — always populates `date` and `rawDateText`
  - Key points: Remaining substantive sentences (> 20 chars, cap 5)
- **FoundationModels enhancement**: Structured section-marker prompt, falls back to rule-based
- **Re-extraction merge**: `mergeInsights()` preserves `isCompleted`, `exportedToReminders`, `exportedToCalendar` by matching text (case-insensitive)

## UI Components (DXWhispUI)
- **NoteCard** — note preview with tag chips, lock indicator, favorite badge
- **TagChipView** — colored tag pill
- **RecordButton** — circular record/stop with duration
- **RecordingAnimationView** — Lottie animation displayed during recording
- **GlassCard** — frosted glass card style
- **ErrorOverlay** / **ProcessingOverlay** — state overlays
- **Theme** — colors, fonts, spacing tokens

## Persistence
- Notes stored as `NoteEnvelope` (version: 1) JSON at `~/Documents/Notes/{UUID}.json`
- Tags stored separately via PersistenceClient
- `.completeFileProtection` on JSON and audio files
- Legacy migration: old `audioURL` → new `audioFilename` format
- Orphan audio cleanup: unreferenced `.m4a` files older than 1 hour
- Atomic writes for crash safety

## TCA Patterns
```swift
@Reducer struct Feature {
    @ObservableState struct State: Equatable { ... }
    enum Action { case delegate(Delegate); ... }
    @Dependency(\.client) var client
    var body: some ReducerOf<Self> { Reduce { state, action in ... } }
}
```
- Child-to-parent: `.delegate` actions — parent handles in `.ifLet` or `Scope`
- Navigation: `@Presents` + `.ifLet(\.$destination, action: \.destination)`
- Dismiss: `state.destination = nil` — NEVER `@Environment(\.dismiss)`
- Cancellation: `CancelID` enum + `.cancellable(id:)` for long-running effects
- Testing: `TestStore` with full exhaustivity — never `.exhaustivity = .off` without justification

## Test Pattern
```swift
@Test func testAction() async {
    let store = TestStore(initialState: Feature.State()) {
        Feature()
    } withDependencies: { $0.client = .mock }
    await store.send(.action) { $0.value = expected }
    await store.receive(\.delegate.result) { $0.other = value }
}
```

## Test Coverage (156 tests, 9 suites)
- **NoteDetailFeatureTests** (48 tests) — playback, export, delete, lock, biometric auth, transcript editing, merge preservation, Pro gates
- **NotesListFeatureTests** (41 tests) — search, filter, tags, bulk ops, favorites, locking, rename, delete, Pro gates
- **AppFeatureTests** (17 tests) — transcription flow, tab switching, note presentation, subscription sync, paywall, Pro gating
- **RecordingFeatureTests** (17 tests) — permission, audio level, recording lifecycle, failure states, free tier limit
- **SubscriptionFeatureTests** (12 tests) — product loading, purchase flows, restore, error handling
- **SettingsFeatureTests** (9 tests) — defaults loading, auto-export toggles, upgrade button, Pro gates
- **OnboardingFeatureTests** (7 tests) — page flow, permissions, completion
- **TagEditorFeatureTests** (6 tests) — create, update, delete tags
- **RootFeatureTests** (3 tests) — onboarding gate

## SwiftUI Performance
- Extract views > 100 lines
- `Equatable` on views with closure params (compare data, skip closures)
- `LazyVStack` / `LazyHStack` for scrollable lists
- Never sort/filter in computed state — memoize in reducer on data change (see `recomputeFilteredNotes()`)
- Debounce search: `.debounce(id:for:scheduler:)` effect
- `@Bindable` for store bindings, `@State` only for local view state

## Code Standards
- No `print()` — `Logger` / `os_log`
- `guard` for early exits, value types over reference types
- Typed error enums, never raw `Error`
- Effects MUST send success/failure actions — no fire-and-forget on state-affecting ops
- `@unchecked Sendable` requires a comment explaining what protects mutable state
- `AsyncStream` continuations: never overwrite, use shared stream pattern
- `try?` only where error genuinely doesn't matter — never for user-facing ops
- Optimistic updates with rollback on failure (see `toggleFavorite`/`toggleFavoriteFailed`)

## Where To Put New Code
- New feature: `DXWhisp/Sources/{FeatureName}/{FeatureName}Feature.swift` + `{FeatureName}View.swift`
- New client: `Packages/DXWhispKit/Sources/DXWhispKit/Clients/{Name}Client.swift`
- New model: `Packages/DXWhispKit/Sources/DXWhispKit/Models/{Name}.swift`
- New UI component: `Packages/DXWhispUI/Sources/DXWhispUI/{Name}.swift`
- New test: `DXWhispTests/{FeatureName}FeatureTests.swift`
- Then add files to Xcode project manually (never edit .pbxproj)

## DO NOT
- Use `ObservableObject` / `@Published` / `@Observable` — TCA uses `@ObservableState`
- Mutate state outside reducers
- Force unwrap without justification
- Use `NavigationView` (use `NavigationStack`)
- Skip effect cancellation for long-running work
- Disable test exhaustivity without documenting why
- Fire-and-forget effects that change user-visible state
