# DXWhisp

**Voice notes that turn into action.** Record meetings, ideas, or quick thoughts — DXWhisp transcribes them with speaker detection and intelligently extracts action items, events, and key points.

## Features

| Feature | Description |
|---------|-------------|
| **Audio-Reactive Waveform** | Real-time 48-bar waveform that responds to your voice levels while recording. |
| **Smart Transcription** | Speech-to-text using Apple's Speech framework — fast and accurate. |
| **Speaker Detection** | Pause-based speaker turn detection labels who said what (up to 6 speakers). |
| **Rule-Based Insights** | NLTokenizer + NSDataDetector extract summaries, action items, events (with real dates), and key points on all iOS versions. |
| **AI-Enhanced Insights** | Foundation Models provide richer extraction with structured section parsing and rule-based fallback. |
| **Transcript Editing** | Edit transcription text in-app; re-extraction preserves completion flags and export state. |
| **Reminders Integration** | Export action items directly to Apple Reminders. |
| **Calendar Integration** | Export detected events and meetings to Calendar — dates always populated via NSDataDetector. |
| **Auto-Export** | Optionally auto-export insights on recording completion (configurable in Settings). |
| **Tags & Filtering** | Organize notes with colored tags (10 colors), filter by tag, search by text. |
| **Bulk Operations** | Multi-select notes for batch delete, favorite, or lock. |
| **Privacy & Security** | Encrypted data protection (`.completeFileProtection`). Lock sensitive notes with Face ID / Touch ID / Optic ID. |
| **Onboarding** | 4-page intro carousel with permission requests (mic, speech, Reminders, Calendar). |

## Architecture

The app uses **The Composable Architecture (TCA)** with unidirectional data flow:

```
┌─────────────────────────────────────────────────────────────┐
│                        RootFeature                          │
│  (Onboarding gate — shows onboarding or app)                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        AppFeature                           │
│  (Tab bar coordinator with transcription orchestration)     │
├─────────────────┬─────────────────┬─────────────────────────┤
│   NotesTab      │   RecordTab     │      SettingsTab        │
│                 │                 │                         │
│ NotesListFeature│ RecordingFeature│    SettingsFeature      │
│       │         │                 │                         │
│  TagEditorF     │                 │                         │
│  (@Presents)    │                 │                         │
├─────────────────┴─────────────────┴─────────────────────────┤
│              NoteDetailFeature (@Presents sheet)             │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
RecordButton tap → AudioRecorderClient.startRecording() → .m4a file
  + AudioRecorderClient.currentAudioLevel() → real-time waveform animation
  → RecordingFeature.delegate(.recordingCompleted(url, duration))
  → AppFeature.processRecording(url, duration)
    → TranscriptionClient.transcribe(url) → Transcription (text + segments + speakerTurns)
    → TranscriptionClient.extractInsights(text) → Insights (NLP rule-based + optional AI)
    → VoiceNote created → PersistenceClient.saveNote → ~/Documents/Notes/{UUID}.json
    → Auto-export: actionItems → Reminders, events → Calendar (if enabled)
    → .transcriptionCompleted(note) → notesList.notes.insert → NoteDetail sheet opens
```

### Key Patterns

- **Reducers**: `@Reducer` macro for composable feature logic
- **State**: `@ObservableState` for reactive SwiftUI bindings
- **Dependencies**: Swift Dependencies for testable dependency injection
- **Delegation**: Child features communicate up via `delegate` actions
- **Presentation**: `@Presents` for sheet/navigation state
- **Memoization**: `recomputeFilteredNotes()` avoids sorting/filtering in computed properties

## Project Structure

```
whisp-ios/
├── DXWhisp/                        # Main app target
│   ├── Sources/
│   │   ├── DXWhispApp.swift        # Entry point (@main)
│   │   ├── App/                    # Tab navigation & transcription orchestration
│   │   ├── Root/                   # Onboarding gate
│   │   ├── Recording/              # Audio capture + audio-reactive waveform
│   │   ├── NotesList/              # Notes browser with search, tags, bulk ops
│   │   │   └── TagEditor           # Tag CRUD with colored chips
│   │   ├── NoteDetail/             # Playback, speaker turns, export, lock/unlock
│   │   ├── Onboarding/             # 4-page intro carousel
│   │   ├── Settings/               # Preferences & integration toggles
│   │   └── Localization/           # L10n strings
│   └── Resources/
│       ├── Assets.xcassets/        # App icons, colors
│       ├── Info.plist              # Bundle configuration
│       └── PrivacyInfo.xcprivacy   # Privacy manifest
│
├── Packages/
│   ├── DXWhispKit/                 # Core logic package (Swift 6.2, iOS 26+)
│   │   ├── Models/                 # VoiceNote, Transcription, Insights, Tag, etc.
│   │   └── Clients/                # 8 dependency clients
│   │       ├── AudioRecorderClient # Record + audio level metering
│   │       ├── AudioPlayerClient   # Playback with seek/pause/resume
│   │       ├── TranscriptionClient # Speech recognition + insight extraction
│   │       ├── PersistenceClient   # JSON storage + orphan cleanup
│   │       ├── EventKitClient      # Reminders + Calendar integration
│   │       ├── BiometricClient     # Face ID / Touch ID / Optic ID
│   │       ├── HapticClient        # Haptic feedback
│   │       └── UserDefaultsClient  # Preferences
│   └── DXWhispUI/                  # Shared UI components
│       ├── RecordButton            # Circular record/stop with pulse
│       ├── WaveformView            # 48-bar audio-reactive waveform
│       ├── NoteCard                # Note preview with tags, lock, favorite
│       ├── TagChipView             # Colored tag pill
│       ├── GlassCard               # Frosted glass card style
│       ├── ErrorOverlay            # Error state overlay
│       └── Theme                   # Colors, fonts, spacing tokens
│
├── DXWhispTests/                   # 127 tests across 8 suites
│
├── DXWhispUITests/                 # Snapshot/screenshot tests
│
├── fastlane/                       # Build automation
│   ├── Fastfile                    # 15 lanes (CI, build, screenshots, distribution)
│   ├── Snapfile                    # Screenshot device config (iOS 26+ devices)
│   ├── Deliverfile                 # App Store submission settings
│   ├── Matchfile                   # Certificate storage config
│   └── metadata/                   # App Store metadata
│
└── .github/workflows/
    ├── ci.yml                      # Build + test + UI test + lint (macOS 26, Xcode 26.2)
    └── deploy.yml                  # TestFlight/App Store deployment
```

## Clients

| Client | Interface |
|--------|-----------|
| **AudioRecorderClient** | `requestPermission`, `prepareSession`, `startRecording`, `stopRecording → URL`, `currentAudioLevel` |
| **AudioPlayerClient** | `play(URL) → AsyncStream`, `pause`, `resume`, `seek(TimeInterval)`, `currentTime` |
| **TranscriptionClient** | `transcribe(URL) → Transcription`, `extractInsights(String) → Insights`, `requestSpeechAuthorization` |
| **PersistenceClient** | `saveNote`, `loadNotes`, `deleteNote`, `updateNote`, `cleanupOrphanedAudio`, `saveTags`, `loadTags` |
| **EventKitClient** | `requestRemindersAccess`, `addReminder`, `requestCalendarAccess`, `addCalendarEvent` |
| **BiometricClient** | `isAvailable`, `biometricType`, `authenticate → Bool` |
| **HapticClient** | `impact(FeedbackStyle)`, `notification(FeedbackType)`, `selection` |
| **UserDefaultsClient** | `getBool(Key)`, `setBool(Key, Bool)` |

## Models

| Model | Key Properties |
|-------|---------------|
| **VoiceNote** | `id`, `createdAt`, `title`, `audioFilename`, `duration`, `transcription?`, `insights?`, `isFavorite`, `isLocked`, `tagIDs` |
| **Transcription** | `text`, `segments: [TranscriptionSegment]`, `speakerTurns: [SpeakerTurn]` |
| **TranscriptionSegment** | `text`, `timestamp`, `duration`, `confidence` |
| **SpeakerTurn** | `speakerLabel`, `text`, `startTime`, `endTime` |
| **Insights** | `summary?`, `actionItems: [ActionItem]`, `events: [ExtractedEvent]`, `keyPoints: [String]` |
| **ActionItem** | `id`, `text`, `isCompleted`, `exportedToReminders` |
| **ExtractedEvent** | `id`, `title`, `date?`, `rawDateText`, `exportedToCalendar` |
| **Tag** | `id`, `name`, `color` (10 colors) |
| **RecordingState** | `.idle`, `.recording(duration:)`, `.processing` |

## Testing

The project uses **Swift Testing** (`@Test`, `#expect`) with TCA's `TestStore` for deterministic reducer testing. Dependencies are mocked via **swift-dependencies**.

**127 tests across 8 suites — ~2,323 lines of test code.**

### Test Coverage

| Suite | Tests | Lines | What's Verified |
|-------|-------|-------|-----------------|
| **NoteDetailFeature** | 44 | 867 | Playback, export, delete, lock, biometric auth, transcript editing, merge preservation |
| **NotesListFeature** | 37 | 782 | Search, filter by tags, bulk ops, favorites, locking, rename, delete |
| **RecordingFeature** | 13 | 177 | Permissions, audio level updates, recording lifecycle, failure states |
| **AppFeature** | 11 | 189 | Tab navigation, transcription flow, note presentation, error states |
| **OnboardingFeature** | 7 | 83 | Page navigation, permission requests, mic/speech grant/denial |
| **TagEditorFeature** | 6 | 62 | Create, update, delete tags with colors |
| **SettingsFeature** | 6 | 109 | Defaults loading, auto-export toggles, onboarding reset |
| **RootFeature** | 3 | 54 | Onboarding gate |

### UI Tests

| Test | What's Verified |
|------|-----------------|
| **testOnboardingScreenshots** | Onboarding flow — navigates all 4 pages and captures screenshots |
| **testMainAppScreenshots** | Main app — verifies tab navigation loads correctly and captures screenshots |

## Build & CI

- **iOS 26+** | Swift 6.2 | Xcode 26.2
- **Bundle ID**: `me.yasirromaya.whisp`
- **SPM packages**: `DXWhispKit` (models + clients), `DXWhispUI` (shared components)
- **Dependency**: swift-dependencies v1.6.0+
- **CI**: GitHub Actions on macOS 26 — build, test, UI test, SwiftLint (concurrent jobs)
- **Deploy**: Manual trigger → TestFlight or App Store via fastlane
- **Fastlane lanes**:
  - CI: `ci_test`, `ci_ui_test`, `ci_build`
  - Code Signing: `certificates`, `certificates_dev`, `certificates_refresh`
  - Build/Test: `build`, `test`
  - Screenshots: `screenshots` (capture), `whisp_frame` (frame with branded backgrounds), `screenshots_and_frame` (both)
  - Distribution: `metadata` (upload metadata only), `beta` (TestFlight), `release` (App Store)
  - Versioning: `bump` (patch|minor|major)

## License

Proprietary. All rights reserved.
