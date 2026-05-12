# Calm Cyan UI Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved Calm Cyan Workspace UI baseline to the Flutter note browser without changing note storage behavior.

**Architecture:** Keep existing domain and repository code unchanged. Update theme tokens in `app_theme.dart`, then rebuild `NoteBrowserPage` presentation widgets around the same state and callbacks.

**Tech Stack:** Flutter, Material 3, Dart widget tests, SQLite repository tests.

---

### Task 1: Theme Tokens

**Files:**
- Modify: `apps/client/lib/app/app_theme.dart`

- [ ] Update `ColorScheme.fromSeed` to use `#0891B2`.
- [ ] Add Card, ListTile, FilledButton, OutlinedButton, TextButton and InputDecoration theme settings.
- [ ] Keep `useMaterial3: true`.
- [ ] Run `flutter test test/widget_test.dart`.
- [ ] Commit as `style: 定义 Calm Cyan 主题基线`.

### Task 2: Note Browser Layout

**Files:**
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`

- [ ] Preserve all existing state fields and repository calls.
- [ ] Replace the default AppBar/Row/ListTile look with a Calm Cyan shell.
- [ ] Implement polished wide layout with top toolbar, folder pane, note list pane and document pane.
- [ ] Implement narrow layout with top toolbar, folder chips, list and detail sections.
- [ ] Keep all user-facing labels used by widget tests: `轻量同步笔记`, `新建`, `编辑`, `保存`, `取消`, `标题`, `正文`.
- [ ] Run `flutter test test/widget_test.dart`.
- [ ] Commit as `style: 应用 Calm Cyan 笔记界面`.

### Task 3: Tests and Docs

**Files:**
- Modify: `apps/client/test/widget_test.dart`
- Modify: `apps/client/README.md`
- Modify: `docs/development/local-run.md`

- [ ] Add widget assertions for `SQLite 已保存` and `搜索标题、正文或链接...`.
- [ ] Update docs to mention the Calm Cyan UI baseline.
- [ ] Run `flutter test`.
- [ ] Commit as `docs: 记录 Calm Cyan UI 基线`.

### Task 4: Final Verification

**Files:**
- Verify: client and backend.

- [ ] Run `dart format lib test` from `apps/client`.
- [ ] Run `flutter pub get`, `flutter analyze`, and `flutter test` from `apps/client`.
- [ ] Run `go test -count=1 ./...` from `services/api`.
- [ ] Run placeholder scan:

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]" apps/client docs/development docs/superpowers/specs/2026-05-13-ui-baseline-calm-cyan-design.md docs/superpowers/plans/2026-05-13-ui-baseline-calm-cyan.md
```

Expected: no output.
