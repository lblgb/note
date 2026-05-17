# Client Sync Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve manual sync with saved cursors, incremental pull, token refresh retry, and a clear relogin dialog.

**Architecture:** Extend existing auth and sync clients instead of adding a new transport layer. Store sync cursor in a small JSON file abstraction, inject it into `NoteSyncService`, and let `AuthGate` own session refresh/logout decisions.

**Tech Stack:** Flutter, Dart `dart:io`, existing `AuthApiClient`, existing `SyncApiClient`, existing widget tests.

---

### Task 1: Refresh Token Client Support

**Files:**
- Modify: `apps/client/lib/features/auth/data/auth_api_client.dart`
- Modify: `apps/client/test/features/auth/data/auth_api_client_test.dart`

- [ ] Add failing test for `refresh` posting `/api/auth/refresh`.
- [ ] Implement `AuthApiClient.refresh`.
- [ ] Verify auth API tests pass.

### Task 2: Sync Cursor Store

**Files:**
- Create: `apps/client/lib/features/sync/data/sync_cursor_store.dart`
- Create: `apps/client/test/features/sync/data/sync_cursor_store_test.dart`

- [ ] Add failing tests for save/load/clear and missing file.
- [ ] Implement file and memory cursor stores.
- [ ] Verify cursor store tests pass.

### Task 3: Incremental Sync Service

**Files:**
- Modify: `apps/client/lib/features/sync/application/note_sync_service.dart`
- Modify: `apps/client/test/features/sync/application/note_sync_service_test.dart`

- [ ] Add failing test proving `pull` uses stored cursor and saves returned version.
- [ ] Implement cursor-aware sync.
- [ ] Verify sync service tests pass.

### Task 4: Auth Refresh Retry And Relogin Dialog

**Files:**
- Modify: `apps/client/lib/features/auth/presentation/auth_gate.dart`
- Modify: `apps/client/lib/features/shell/shell_page.dart`
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`
- Modify: `apps/client/test/widget_test.dart`

- [ ] Add failing widget tests for refresh retry and relogin dialog.
- [ ] Pass refresh-capable sync action from `AuthGate`.
- [ ] Show relogin dialog on unrecoverable auth failure.
- [ ] Verify widget tests pass.

### Task 5: Docs And Full Verification

**Files:**
- Modify: `apps/client/README.md`
- Modify: `docs/development/local-run.md`

- [ ] Document token refresh and relogin behavior.
- [ ] Run `flutter --no-version-check test`.
- [ ] Run `go test -count=1 ./...`.
- [ ] Commit, merge to master, and push.

## Self Review

- Scope is limited to manual sync polish, cursor persistence, and token refresh.
- No placeholders remain.
- Type names are consistent with existing `AuthApiClient`, `NoteSyncService`, and `SyncApiClient`.
