# SQLite Note Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist folders and notes in a local SQLite database so edits survive app restarts.

**Architecture:** Keep `NoteRepository` as the page-facing boundary. Add a SQLite-backed repository and let `NoteBrowserPage` initialize it asynchronously when no test repository is injected.

**Tech Stack:** Flutter, Dart, `sqlite3`, `path`, Flutter widget tests, Dart unit tests.

---

### Task 1: Add SQLite Dependencies

**Files:**
- Modify: `apps/client/pubspec.yaml`
- Modify: `apps/client/pubspec.lock`

- [ ] Add `sqlite3: ^3.3.1` and `path: ^1.9.1` under client dependencies.
- [ ] Add `hooks.user_defines.sqlite3` so Windows uses the system `winsqlite3.dll`.
- [ ] Run `flutter pub get` from `apps/client`.
- [ ] Commit as `build: 添加 SQLite 客户端依赖`.

### Task 2: Add Repository Persistence Tests

**Files:**
- Create: `apps/client/test/features/notes/data/sqlite_note_repository_test.dart`

- [ ] Write tests for first-open seed data, created-note persistence after reopen, and edited-note persistence after reopen.
- [ ] Run `flutter test test/features/notes/data/sqlite_note_repository_test.dart`.
- [ ] Confirm the test run fails because `SqliteNoteRepository` does not exist yet.

### Task 3: Implement SQLite Repository

**Files:**
- Create: `apps/client/lib/features/notes/data/sqlite_note_repository.dart`
- Test: `apps/client/test/features/notes/data/sqlite_note_repository_test.dart`

- [ ] Create `SqliteNoteRepository` implementing `NoteRepository`.
- [ ] Add `open()` for the default database path and `openForPath(String databasePath)` for tests.
- [ ] Create `folders`, `notes`, and `meta` tables on database version 1.
- [ ] Seed the same default folders and notes as the in-memory repository once by using `meta.seeded = true`.
- [ ] Implement `listFolders`, `listNotes`, `findNote`, `createNote`, `updateNote`, and `close`.
- [ ] Store dates with `DateTime.toIso8601String()` and read dates with `DateTime.parse()`.
- [ ] Run `flutter test test/features/notes/data/sqlite_note_repository_test.dart`.
- [ ] Commit as `feat: 添加 SQLite 笔记仓储`.

### Task 4: Wire SQLite Into App Startup

**Files:**
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`
- Modify: `apps/client/test/widget_test.dart`

- [ ] Add a widget test that verifies the default page initially shows `正在加载笔记...`.
- [ ] Run `flutter test test/widget_test.dart` and confirm the new loading test fails before implementation.
- [ ] Change `NoteBrowserPage` so injected repositories still initialize synchronously for tests.
- [ ] When no repository is injected, call `SqliteNoteRepository.open()` asynchronously.
- [ ] Show `正在加载笔记...` while loading.
- [ ] Show `笔记数据库初始化失败` and a `重试` button if initialization fails.
- [ ] Run `flutter test test/widget_test.dart`.
- [ ] Commit as `feat: 接入 SQLite 默认笔记仓储`.

### Task 5: Update Docs

**Files:**
- Modify: `apps/client/README.md`
- Modify: `docs/development/flutter-setup.md`
- Modify: `docs/development/local-run.md`

- [ ] Document that folders and notes now persist through SQLite.
- [ ] Keep images, tags, internal link indexes, and sync listed as planned capabilities.
- [ ] Commit as `docs: 更新 SQLite 本地保存说明`.

### Task 6: Final Verification

**Files:**
- Verify: client and backend.

- [ ] Run `dart format lib test` from `apps/client`.
- [ ] Run `flutter pub get`, `flutter analyze`, and `flutter test` from `apps/client`.
- [ ] Run `go test -count=1 ./...` from `services/api`.
- [ ] Run placeholder scan:

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]" apps/client docs/development docs/superpowers/specs/2026-05-12-sqlite-note-storage-design.md docs/superpowers/plans/2026-05-12-sqlite-note-storage.md
```

Expected: no output.
