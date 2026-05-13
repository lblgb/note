# Flutter Auth Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Flutter registration/login/logout gate that persists local auth session state before showing the note browser.

**Architecture:** Add a focused auth feature under `apps/client/lib/features/auth`. The API client handles JSON HTTP calls, the session store persists `AuthSession` to a local JSON file, `AuthGate` switches between auth UI and the existing shell, and `NoteBrowserPage` only receives an optional logout callback.

**Tech Stack:** Flutter, Dart `HttpClient`, Dart `File`, existing Go auth API contract, `flutter_test`.

---

### Task 1: Auth Models And API Client

**Files:**
- Create: `apps/client/lib/features/auth/domain/auth_session.dart`
- Create: `apps/client/lib/features/auth/data/auth_api_client.dart`
- Test: `apps/client/test/features/auth/data/auth_api_client_test.dart`

- [ ] **Step 1: Write failing API client tests**

Cover successful login response parsing, successful register response parsing, server JSON error mapping, and network error mapping.

Run: `flutter test test/features/auth/data/auth_api_client_test.dart`

Expected: FAIL because auth files do not exist.

- [ ] **Step 2: Implement models and client**

Create `AuthUser`, `AuthSession`, `AuthApiException`, and `AuthApiClient`. Use `HttpClient` by default, accept an injectable transport function in tests, and send JSON to `/api/auth/register`, `/api/auth/login`, and `/api/auth/logout`.

- [ ] **Step 3: Verify API client tests**

Run: `flutter test test/features/auth/data/auth_api_client_test.dart`

Expected: PASS.

- [ ] **Step 4: Commit API client**

Run:

```bash
git add apps/client/lib/features/auth/domain/auth_session.dart apps/client/lib/features/auth/data/auth_api_client.dart apps/client/test/features/auth/data/auth_api_client_test.dart
git commit -m "feat: add Flutter auth API client"
```

### Task 2: Session Store

**Files:**
- Create: `apps/client/lib/features/auth/data/auth_session_store.dart`
- Test: `apps/client/test/features/auth/data/auth_session_store_test.dart`

- [ ] **Step 1: Write failing session store tests**

Cover save/load, clear, missing file, and corrupt JSON fallback.

Run: `flutter test test/features/auth/data/auth_session_store_test.dart`

Expected: FAIL because `AuthSessionStore` does not exist.

- [ ] **Step 2: Implement store**

Create `AuthSessionStore` interface, `MemoryAuthSessionStore` for widget tests, and `FileAuthSessionStore` for runtime. Store UTF-8 JSON in `auth_session.json`.

- [ ] **Step 3: Verify session store tests**

Run: `flutter test test/features/auth/data/auth_session_store_test.dart`

Expected: PASS.

- [ ] **Step 4: Commit session store**

Run:

```bash
git add apps/client/lib/features/auth/data/auth_session_store.dart apps/client/test/features/auth/data/auth_session_store_test.dart
git commit -m "feat: persist Flutter auth sessions"
```

### Task 3: Auth UI And Gate

**Files:**
- Create: `apps/client/lib/features/auth/presentation/auth_gate.dart`
- Create: `apps/client/lib/features/auth/presentation/auth_page.dart`
- Test: `apps/client/test/features/auth/presentation/auth_gate_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover no session shows login page, existing session shows note browser, login success switches to notes, and logout returns to auth page.

Run: `flutter test test/features/auth/presentation/auth_gate_test.dart`

Expected: FAIL because auth presentation files do not exist.

- [ ] **Step 2: Implement auth page**

Create a Calm Cyan compatible form with login/register mode switch, email, password, display name in register mode, submit loading state, and error text.

- [ ] **Step 3: Implement auth gate**

Load session on init, render loading state, call API on login/register, save session, and pass logout callback to `ShellPage`.

- [ ] **Step 4: Verify widget tests**

Run: `flutter test test/features/auth/presentation/auth_gate_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit auth UI**

Run:

```bash
git add apps/client/lib/features/auth/presentation/auth_gate.dart apps/client/lib/features/auth/presentation/auth_page.dart apps/client/test/features/auth/presentation/auth_gate_test.dart
git commit -m "feat: add Flutter auth gate"
```

### Task 4: App Wiring And Docs

**Files:**
- Modify: `apps/client/lib/app/note_app.dart`
- Modify: `apps/client/lib/features/shell/shell_page.dart`
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`
- Modify: `apps/client/test/widget_test.dart`
- Modify: `apps/client/README.md`

- [ ] **Step 1: Write failing app wiring test**

Update widget tests so injected repository still reaches note browser through `AuthGate` when a memory session exists.

Run: `flutter test test/widget_test.dart`

Expected: FAIL before `NoteApp` is wired through `AuthGate`.

- [ ] **Step 2: Wire root app**

Make `NoteApp` create default `AuthApiClient` and `FileAuthSessionStore`, then render `AuthGate`. Keep constructor injection for tests.

- [ ] **Step 3: Add logout entry**

Pass `onLogout` through `ShellPage` into `NoteBrowserPage` and show a compact `退出` button in `_TopToolbar` when callback exists.

- [ ] **Step 4: Update README**

Document API server prerequisite, default base URL, Android emulator host URL, and auth verification steps.

- [ ] **Step 5: Verify widget tests**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit app wiring**

Run:

```bash
git add apps/client/lib/app/note_app.dart apps/client/lib/features/shell/shell_page.dart apps/client/lib/features/notes/presentation/note_browser_page.dart apps/client/test/widget_test.dart apps/client/README.md
git commit -m "feat: wire auth gate into Flutter app"
```

### Task 5: Final Verification And Push

**Files:**
- Inspect all changed files.

- [ ] **Step 1: Run full Flutter tests**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 2: Run Flutter analyzer**

Run: `flutter analyze`

Expected: no analyzer errors.

- [ ] **Step 3: Review diff**

Run: `git diff --stat master...HEAD` and `git diff --name-only master...HEAD`.

Expected: auth client, docs, app wiring, and tests only.

- [ ] **Step 4: Push branch**

Run: `git push -u origin feature/flutter-auth-client`.

Expected: branch is available on GitHub.
