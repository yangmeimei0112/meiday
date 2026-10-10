# Project: ChronoHub

## Architecture
- **Paradigm**: Local-First, Offline-First Single Source of Truth with Cloud-Assisted Synchronization.
- **Framework**: Flutter (cross-platform: Windows desktop, Android, iOS, macOS, Web).
- **Data Persistence**: Drift (SQLite) with physical multi-tenant database isolation (`guest.db` vs `user_${sha256(uid)}.db`).
- **State Management & DI**: Flutter Riverpod 2.x (functional notifiers, sealed state machines, pure DI via Provider overrides).
- **Platform Abstraction Layer**: Interface-driven services (`OcrService`, `NotificationService`, `TrayService`, `AudioService`, `WidgetSyncService`, `SecureStorageService`) with mock test doubles for headless Dart VM test execution.
- **Data Flow**:
  1. UI / Gestures / Hotkeys mutate local Drift SQLite within an atomic transaction.
  2. Transaction simultaneously writes mutation records to `sync_outbox` with Last-Write-Wins (LWW) version timestamps.
  3. UI reactively updates via Drift reactive queries / Riverpod streams with sub-millisecond local latency.
  4. Background Sync Service processes `sync_outbox` to Supabase (PostgreSQL + Realtime + RLS) and listens to remote changes via WebSocket.
  5. Multi-space events link through `event_space_links` junction table ensuring zero duplicated data.

## Code Layout
```
lib/
├── app/
│   ├── app.dart                        # ChronoHubApp (MaterialApp, theme, localization)
│   ├── router.dart                     # GoRouter configuration & auth redirect guard
│   └── theme/                          # ThemeMode, ColorPalette, GlassmorphismStyles
├── core/
│   ├── constants/                      # App constants, routes, table names
│   ├── database/                       # Drift SQLite engine & DAOs
│   │   ├── app_database.dart           # @DriftDatabase definition
│   │   ├── connection/                 # Connection factories (native file & in-memory)
│   │   ├── daos/                       # OutboxDao, DeviceDao, SyncMetaDao
│   │   └── migrations/                 # guest_migration_executor.dart
│   ├── errors/                         # Failure types and exception handling
│   ├── platform/                       # Platform service interfaces & platform implementations
│   │   ├── ocr_service.dart            # OcrService (WinRT, ML Kit, BYOK, Mock)
│   │   ├── notification_service.dart   # NotificationService (Local, WebSocket, Mock)
│   │   ├── tray_service.dart           # TrayService (system_tray, window_manager, Mock)
│   │   ├── audio_service.dart          # AudioService (audioplayers, Mock)
│   │   ├── widget_service.dart         # WidgetSyncService (home_widget, Tray, Mock)
│   │   └── secure_storage_service.dart # SecureStorageService (DPAPI/KeyStore, Mock)
│   └── utils/                          # Clock utilities, hash generators, extensions
├── features/
│   ├── auth/                           # R1: Guest mode, Email/Magic Link, multi-device sessions
│   ├── calendar/                       # R2: Multi-view canvas, Time-blocking, Auto-Cascade, Undo stack
│   ├── social/                         # R3: Spaces, Linked Mirroring, In-event cards, Keep pool, Heatmap
│   ├── capture/                        # R4: Bilingual NLP Quick-Add, polymorphic OCR
│   ├── focus/                          # R4: Pomodoro timer, ambient white noise generator
│   └── sync/                           # R5: Outbox sync engine, Supabase integration, native widgets
test/
├── unit/                               # Pure Dart algorithmic and state tests
├── widget/                             # Flutter UI widget and gesture tests
├── integration/                        # Multi-module E2E simulation tests
└── e2e/                                # Requirement-driven opaque-box verification test suites
```

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Scaffolding & Core Architecture | Flutter project setup, Riverpod DI, Clean Architecture directory structure | M0 | env_survey |
| 2 | Drift Multi-Database Infrastructure | Dynamic `DatabaseConnectionFactory` (`guest.db` vs `user_${uid}.db` & in-memory) | M0 | arch_survey |
| 3 | Platform Abstraction Interfaces | Abstract services & mock doubles for OCR, Tray, Audio, Notification, Storage | M0 | arch_survey |
| 4 | Zero-Friction Guest Mode | Launch and use full functionality immediately without login | M1 | PRD §3.1 / R1 |
| 5 | Email & Password Authentication | Sign up, login, password recovery with JWT & Refresh token lifecycle | M1 | PRD §3.1 / R1 |
| 6 | Magic Link Passwordless Auth | Email magic link login with deep-link token validation | M1 | PRD §3.1 / R1 |
| 7 | Secure Token Storage | Store auth session via DPAPI (Windows), Keychain (macOS/iOS), KeyStore (Android) | M1 | PRD §3.1 / R1 |
| 8 | Physical SQLite Multi-Tenant DB | Strict physical database isolation (`guest.db` vs `user_${sha256(uid)}.db`) | M1 | PRD §3.2 / R1 |
| 9 | Safe Logout & Database Severing | Immediate connection closure, memory state wipe, fallback to guest database | M1 | PRD §3.2 / R1 |
| 10 | Transactional Guest Data Migration | Atomic migration of guest records to new user database on first signup | M1 | PRD §3.3 / R1 |
| 11 | Migration Conflict Resolver | Resolution dialog for existing accounts (Merge Local vs Discard Local) | M1 | PRD §3.3 / R1 |
| 12 | Multi-Device Session Registry | `user_devices` tracking active terminals (device name, OS, IP, last active) | M1 | PRD §3.4 / R1 |
| 13 | Remote Session Kickout | Terminate remote sessions via WebSocket broadcast notification | M1 | PRD §3.4 / R1 |
| 14 | Month Calendar View | Grid month view with event badges, overflow indicators, and day selection | M2 | PRD §2 / R2 |
| 15 | Week Calendar View | 7-day multi-column time grid with 15-minute time block snapping | M2 | PRD §2 / R2 |
| 16 | Vertical Visual Timeline View | ADHD-friendly vertical day timeline with high-contrast activity icons | M2 | PRD §2 / R2 |
| 17 | Time-Blocking Drag & Drop | Drag tasks from inbox/drawer directly onto canvas time blocks | M2 | PRD §2 / R2 |
| 18 | Dual-Track Event Classification | Track 1 Anchored events (solid blocks) vs Track 2 Flexible tasks (bordered) | M2 | PRD §2 / R2 |
| 19 | Auto-Cascade Buffer Compression | Automatically compress downstream idle buffers when tasks run overtime | M2 | PRD §2 / R2 |
| 20 | Non-Blocking Collision Banner | Halt cascade and display proposal banner when flexible task collides with anchor | M2 | PRD §2 / R2 |
| 21 | Daily Capacity Bar | Top-bar workload tracker accumulating focus hours (>8h soft warning) | M2 | PRD §2 / R2 |
| 22 | Global Undo/Redo Stack | Command-pattern `Ctrl+Z` / `Cmd+Z` reversing single and composite operations | M2 | PRD §2 / R2 |
| 23 | Command Palette (`Ctrl+K`) | Keyboard-driven quick search and command execution panel | M2 | PRD §2 / R2 |
| 24 | 60s Chrono-Review Ritual | Morning/evening modal to review, defer, or complete pending tasks | M2 | PRD §2 / R2 |
| 25 | Multi-Calendar Spaces | Isolated spaces (Personal, Partner, Family, Team) with custom colors & emojis | M3 | PRD §2 / R3 |
| 26 | Linked Mirroring Engine | Project single event into multiple spaces via `event_space_links` junction | M3 | PRD §2 / R3 |
| 27 | In-Event Discussion Comments | Comment thread attached to individual event card with offline write | M3 | PRD §2 / R3 |
| 28 | In-Event Photo Attachments | Image file attachments and thumbnail previews per calendar event | M3 | PRD §2 / R3 |
| 29 | Shared Grocery & Task Checklist | In-event checklist with instant item checkoff and state synchronization | M3 | PRD §2 / R3 |
| 30 | Keep Inspiration Pool | Unscheduled ideas inbox with one-drag conversion to scheduled time blocks | M3 | PRD §2 / R3 |
| 31 | Multi-Person Availability Heatmap | Aggregate member free/busy schedules to highlight optimal meeting slots | M3 | PRD §2 / R3 |
| 32 | Bilingual NLP Time Parser | Chinese/English natural language parser for dates, times, durations, recurrence | M3 | PRD §2 / R4 |
| 33 | Polymorphic Offline OCR Service | Abstract `OcrService` routing to WinRT on Windows and ML Kit on mobile | M4 | PRD §4 / R4 |
| 34 | Windows Native WinRT OCR Engine | 0-cost, 100% offline text extraction via `Windows.Media.Ocr.OcrEngine` | M4 | PRD §4 / R4 |
| 35 | Mobile Google ML Kit OCR | Offline image text recognition for Android and iOS devices | M4 | PRD §4 / R4 |
| 36 | OCR BYOK Cloud Fallback | Settings option to provide OpenAI/Gemini/Ollama API key for complex layouts | M4 | PRD §4 / R4 |
| 37 | Task-Associated Pomodoro Timer | 25/5 focus & break timer tied to active calendar task with session counting | M4 | PRD §2 / R4 |
| 38 | Ambient White Noise Generator | Seamless looping audio tracks (rain, ocean waves, fan, white noise) | M4 | PRD §2 / R4 |
| 39 | 3-Tier Notification Coordination | Online instant dismiss, push collapse-id folding, app-resume batch alignment | M4 | PRD §4 / R4 |
| 40 | Drift SQLite Outbox Mutation Queue | Transactional `sync_outbox` capturing local mutations with operation types | M5 | PRD §4 / R5 |
| 41 | Last-Write-Wins (LWW) Versioning | Timestamp and version resolution preventing stale data overwrites | M5 | PRD §4 / R5 |
| 42 | Supabase Cloud Database & RLS | PostgreSQL schema with Row-Level Security policies for multi-tenant spaces | M5 | PRD §4 / R5 |
| 43 | Idempotent RPC Queue Fallback | Batch RPC synchronization with client UUID idempotency keys for edge networks | M5 | PRD §4 / R5 |
| 44 | Windows System Tray & Mini Calendar | System tray icon with <0.2s instant popup mini calendar and quick checklist | M5 | PRD §2 / R5 |
| 45 | Global Quick-Capture (`Win+Shift+C`) | System-wide hotkey launching quick-capture modal from anywhere in Windows | M5 | PRD §2 / R5 |
| 46 | Mobile `home_widget` Integration | Shared today JSON snapshot (<5MB) powering iOS/Android home screen widgets | M5 | PRD §4 / R5 |
| 47 | External Calendar Mobile Relay | Bi-directional bridge to Google/Apple Calendar via mobile device calendar | M5 | PRD §4 / R5 |
| 48 | External Calendar Desktop OAuth | Loopback Google OAuth Plan B for desktop sync without CASA review | M5 | PRD §4 / R5 |
| 49 | E2E Automated Verification Suite | Comprehensive Tier 1-4 opaque-box test suites validating 100% pass | M-Final | REQ §35-39 |
| 50 | Adversarial Coverage Hardening | White-box edge case testing and code-path mutation hardening | M-Final | REQ §35-39 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M0 | Scaffolding & Core Architecture | Features #1-#3: Flutter project scaffolding, Riverpod DI, Drift multi-database connection factory, platform service interfaces & test doubles | none | DONE |
| M1 | User Auth & Physical Database Isolation | Features #4-#13: Guest mode, Email/Magic link, DPAPI/Keychain storage, `guest.db` vs `user_${uid}.db`, atomic migration, session registry | M0 | DONE |
| M2 | Canvas & Anti-Fragile Scheduling | Features #14-#24: Month/Week/Timeline views, time-blocking, Auto-Cascade buffer compression, non-blocking banner, Undo stack (`Ctrl+Z`), `Ctrl+K` | M0 | DONE |
| M3 | Social Engine & Linked Mirroring | Features #25-#31: Calendar spaces, `event_space_links` Linked Mirroring, in-event comments, photo attachments, checklists, Keep pool, heatmap | M0, M2 | DONE |
| M4 | Multimodal Capture & GTD Focus Suite | Features #32-#39: Bilingual NLP parser, WinRT/MLKit offline OCR polymorphism, Pomodoro timer, white noise audio loops, 3-tier notifications | M0, M2 | DONE |
| M5 | Local-First Sync & Native Integrations | Features #40-#48: Outbox mutation queue, LWW versioning, Supabase sync & RLS, system tray mini-calendar, `Win+Shift+C` hotkey, home_widget, calendar relay | M0, M1, M3 | DONE |
| M-Final | E2E Test Pass & Adversarial Hardening | Features #49-#50: Phase 1 pass 100% of E2E test suites (Tiers 1-4); Phase 2 white-box adversarial coverage hardening (Tier 5) | M1, M2, M3, M4, M5, E2E-Track | DONE |


## Interface Contracts

### Auth ↔ Database Connection Lifecycle
- **Contract**: `DatabaseConnectionFactory` provides `AppDatabase openDatabase(String? userId)`.
  - When `userId == null` -> opens `guest.db` in app support directory.
  - When `userId != null` -> opens `user_${sha256(userId)}.db`.
  - When auth state switches (login/logout) -> active database instance is safely closed via `AppDatabase.close()`, memory cache purged, and target database initialized.
- **Migration Contract**: `GuestMigrationExecutor.migrate(AppDatabase guestDb, AppDatabase userDb, String userId)`
  - Executes inside atomic SQLite transaction on `userDb`.
  - Migrates all spaces, events, event_space_links, checklists, and keep items.
  - Enqueues corresponding Outbox entries with `op = 'INSERT'`.
  - Purges `guestDb` tables upon successful commit.

### Scheduling Engine ↔ Canvas Views
- **Contract**: `AutoCascadeScheduler.schedule({required List<CalendarEvent> existingEvents, required CalendarEvent movingEvent, required DateTime targetTime})`
  - Returns `ScheduleResult(List<CalendarEvent> shiftedEvents, List<ScheduleConflict> conflicts)`.
  - Track 1 (Anchors: `isAnchor == true`): Immutable in position; shifts cannot displace them.
  - Track 2 (Flexible: `isAnchor == false`): Shifted downstream, compressing buffer gaps.
  - Collision with Anchor: Emits `ScheduleConflict.halted(collidingAnchor, proposedTime)` triggering non-blocking UI proposal banner.
  - Atomic undo: Emits `CascadeScheduleCommand` recorded on `UndoStack`.

### Social Spaces ↔ Linked Mirroring
- **Contract**: `EventRepository.linkEventToSpaces(String eventId, List<String> spaceIds)`
  - Writes records to `event_space_links(event_id, space_id, created_at)`.
  - Queries for space `S` execute: `SELECT e.* FROM calendar_events e INNER JOIN event_space_links l ON e.id = l.event_id WHERE l.space_id = ?`.
  - Updates to `calendar_events` automatically reflect across all linked spaces.

### Multimodal Capture ↔ Event Creation
- **Contract**: `NlpParser.parse(String rawText, {DateTime? referenceTime})`
  - Returns `NlpParseResult(String cleanTitle, DateTime? startTime, DateTime? endTime, bool isAllDay, String? recurrenceRule, List<String> tags)`.
- **Contract**: `OcrService.extractText(Uint8List imageBytes)`
  - Returns `Future<OcrResult(String recognizedText, double confidence)>`.
  - Seamlessly pipelines into `NlpParser.parse(recognizedText)`.

### Local Persistence ↔ Supabase Outbox Sync
- **Contract**: `OutboxSyncWorker.syncPendingMutations()`
  - Queries `SELECT * FROM sync_outbox WHERE status = 'PENDING' ORDER BY created_at ASC`.
  - Sends batch mutations to Supabase with client `mutation_id` (UUID idempotency key).
  - Handles LWW conflict resolution: remote update accepted only if `remote.updated_at > local.updated_at`.
  - Updates local outbox record to `'SYNCED'`.
