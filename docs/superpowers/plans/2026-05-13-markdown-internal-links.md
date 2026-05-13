# Markdown Internal Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Markdown preview and internal note links to the Flutter note detail view.

**Architecture:** Keep parsing and resolution outside the page widget. `NoteLinkResolver` expands wiki links and resolves internal hrefs through `NoteRepository`; `MarkdownNoteBody` renders Markdown and delegates successful internal navigation back to `NoteBrowserPage`.

**Tech Stack:** Flutter, Dart, `flutter_markdown_plus`, existing `NoteRepository`, existing widget tests.

---

### Task 1: Add Link Resolver

**Files:**
- Create: `apps/client/lib/features/notes/application/note_link_resolver.dart`
- Test: `apps/client/test/features/notes/application/note_link_resolver_test.dart`

- [ ] **Step 1: Write failing resolver tests**

Add tests for wiki expansion, ID resolution, duplicate-title newest resolution, missing target handling, and external link detection.

Run: `flutter test test/features/notes/application/note_link_resolver_test.dart`

Expected: FAIL because `note_link_resolver.dart` does not exist.

- [ ] **Step 2: Implement minimal resolver**

Create `NoteLinkResolver` with `expandWikiLinks`, `isInternalHref`, and `resolve` methods. Use exact ID matching for `note:` and exact title matching for `note-title:`.

- [ ] **Step 3: Verify resolver tests**

Run: `flutter test test/features/notes/application/note_link_resolver_test.dart`

Expected: PASS.

- [ ] **Step 4: Commit resolver**

Run:

```bash
git add apps/client/lib/features/notes/application/note_link_resolver.dart apps/client/test/features/notes/application/note_link_resolver_test.dart
git commit -m "feat: add note link resolver"
```

### Task 2: Add Markdown Rendering Dependency And Widget

**Files:**
- Modify: `apps/client/pubspec.yaml`
- Modify: `apps/client/pubspec.lock`
- Create: `apps/client/lib/features/notes/presentation/markdown_note_body.dart`

- [ ] **Step 1: Add dependency**

Run from `apps/client`: `flutter pub add flutter_markdown_plus`

Expected: `pubspec.yaml` contains `flutter_markdown_plus`, and `pubspec.lock` is updated.

- [ ] **Step 2: Implement `MarkdownNoteBody`**

Render `NoteLinkResolver.expandWikiLinks(content)` with `MarkdownBody`. Handle internal links with `onNoteSelected`; show `未找到笔记` when resolution fails; show `外部链接跳转将在后续支持` for non-internal links.

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`

Expected: no analyzer errors.

- [ ] **Step 4: Commit Markdown widget**

Run:

```bash
git add apps/client/pubspec.yaml apps/client/pubspec.lock apps/client/lib/features/notes/presentation/markdown_note_body.dart
git commit -m "feat: render markdown note body"
```

### Task 3: Wire Detail Pane Navigation

**Files:**
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`
- Modify: `apps/client/test/widget_test.dart`

- [ ] **Step 1: Write failing widget test**

Add a widget test that creates a note containing `[[工作计划]]`, opens it, taps the rendered link, and expects the selected note title to become `工作计划`.

Run: `flutter test test/widget_test.dart`

Expected: FAIL before UI wiring.

- [ ] **Step 2: Wire repository and callback through page widgets**

Add `_openLinkedNote(Note note)` to update selected folder, selected note, and editing state. Pass `repository` and the callback into `_NoteDetailPane`, replacing the raw content `Text` with `MarkdownNoteBody`.

- [ ] **Step 3: Verify widget tests**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

- [ ] **Step 4: Commit UI wiring**

Run:

```bash
git add apps/client/lib/features/notes/presentation/note_browser_page.dart apps/client/test/widget_test.dart
git commit -m "feat: navigate internal note links"
```

### Task 4: Final Verification And Push

**Files:**
- Inspect all changed files.

- [ ] **Step 1: Run full test suite**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`

Expected: no analyzer errors.

- [ ] **Step 3: Review diff**

Run: `git diff --stat master...HEAD` and `git diff master...HEAD -- apps/client/lib apps/client/test docs apps/client/pubspec.yaml apps/client/pubspec.lock`.

Expected: only Markdown/internal-link related changes.

- [ ] **Step 4: Push branch**

Run: `git push -u origin feature/markdown-internal-links`.

Expected: branch is available on GitHub for review or merge.
