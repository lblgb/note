# Client Manual Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manual Flutter sync action that pushes local folders and notes to the Go API, pulls remote state, and writes it into local SQLite.

**Architecture:** Add a focused sync data client, a sync application service, and small repository extension methods. Pass the authenticated session from `AuthGate` into `ShellPage` and `NoteBrowserPage` so the toolbar can call sync with the access token.

**Tech Stack:** Flutter, Dart, `dart:io` `HttpClient`, existing SQLite repository, existing widget tests.

---

### Task 1: Local Repository Sync Methods

**Files:**
- Modify: `apps/client/lib/features/notes/data/note_repository.dart`
- Modify: `apps/client/lib/features/notes/data/sqlite_note_repository.dart`
- Modify: `apps/client/lib/features/notes/data/in_memory_note_repository.dart`
- Test: `apps/client/test/features/notes/data/sqlite_note_repository_test.dart`

- [ ] Write failing tests for `listAllNotes`, `upsertFolder`, and `upsertNote`.
- [ ] Run `flutter --no-version-check test test/features/notes/data/sqlite_note_repository_test.dart` and verify failure.
- [ ] Implement the repository methods in SQLite and memory repositories.
- [ ] Run the same test and verify it passes.

### Task 2: Sync API Client

**Files:**
- Create: `apps/client/lib/features/sync/data/sync_api_client.dart`
- Create: `apps/client/test/features/sync/data/sync_api_client_test.dart`

- [ ] Write failing tests for push path, pull path, authorization header, and error mapping.
- [ ] Run `flutter --no-version-check test test/features/sync/data/sync_api_client_test.dart` and verify failure.
- [ ] Implement `SyncApiClient`, `SyncFolder`, `SyncNote`, `SyncPushInput`, and `SyncPullResult`.
- [ ] Run the same test and verify it passes.

### Task 3: Sync Application Service

**Files:**
- Create: `apps/client/lib/features/sync/application/note_sync_service.dart`
- Create: `apps/client/test/features/sync/application/note_sync_service_test.dart`

- [ ] Write failing test that local notes are pushed, pulled notes are upserted, and server version is returned.
- [ ] Run `flutter --no-version-check test test/features/sync/application/note_sync_service_test.dart` and verify failure.
- [ ] Implement `NoteSyncService.syncNow`.
- [ ] Run the same test and verify it passes.

### Task 4: UI Wiring

**Files:**
- Modify: `apps/client/lib/app/note_app.dart`
- Modify: `apps/client/lib/features/shell/shell_page.dart`
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`
- Test: `apps/client/test/widget_test.dart`

- [ ] Write failing widget test that tapping `同步` calls the sync service and shows `已同步`.
- [ ] Run `flutter --no-version-check test test/widget_test.dart` and verify failure.
- [ ] Pass `AuthSession` and sync dependencies through the app shell.
- [ ] Add toolbar sync button and status state.
- [ ] Run the same test and verify it passes.

### Task 5: Docs And Verification

**Files:**
- Modify: `apps/client/README.md`
- Modify: `docs/development/local-run.md`

- [ ] Document manual sync verification steps.
- [ ] Run `flutter --no-version-check test`.
- [ ] Commit with `feat: 接入客户端手动同步`.

## Self Review

- Spec coverage: local repository, API client, sync service, UI trigger, docs, and tests are covered.
- Placeholder scan: no implementation placeholder remains.
- Type consistency: sync types are consistently named with `Sync*`, and app service is `NoteSyncService`.
