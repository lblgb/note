# Server Sync API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first Go API sync surface for folders and notes using SQLite-backed push and pull.

**Architecture:** Add a focused `internal/sync` package for domain models, repository, service, and HTTP handlers. Keep auth untouched except for reusing the existing bearer-token middleware path in `server.NewWithRepository`.

**Tech Stack:** Go 1.22, `database/sql`, `modernc.org/sqlite`, `net/http`, existing `httpjson` helpers.

---

### Task 1: Sync Domain And Repository Contract

**Files:**
- Create: `services/api/internal/sync/models.go`
- Create: `services/api/internal/sync/repository.go`
- Test: `services/api/internal/sync/memory_repository_test.go`

- [ ] **Step 1: Write the failing test**

Create a test that saves one folder and one note for `usr_1`, then pulls since `0` and expects both entities plus increasing versions.

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/sync`

Expected: package or symbols missing.

- [ ] **Step 3: Write minimal implementation**

Define `Folder`, `Note`, `PushInput`, `PushResult`, `PullResult`, `Repository`, and `MemoryRepository` with `Push` and `Pull`.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/sync`

Expected: sync package tests pass.

### Task 2: SQLite Sync Repository

**Files:**
- Create: `services/api/internal/sync/sqlite_repository.go`
- Create: `services/api/internal/sync/sqlite_repository_test.go`

- [ ] **Step 1: Write the failing persistence test**

Create a test that opens a temp SQLite DB, pushes folder and note, closes and reopens, then pulls since `0`.

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/sync`

Expected: `OpenSQLiteRepository` or persistence implementation missing.

- [ ] **Step 3: Write minimal SQLite implementation**

Create tables `sync_folders`, `sync_notes`, and `sync_changes`; write all pushed entities in a transaction; assign monotonically increasing versions.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/sync`

Expected: sync repository tests pass.

### Task 3: Sync HTTP Handlers

**Files:**
- Create: `services/api/internal/sync/handlers.go`
- Create: `services/api/internal/sync/handlers_test.go`

- [ ] **Step 1: Write failing handler tests**

Test `Push` accepts valid JSON and returns assigned versions; test `Pull` accepts `since` and returns changed entities; test invalid JSON returns `400`.

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/sync`

Expected: handler symbols missing.

- [ ] **Step 3: Write minimal handlers**

Implement `Handlers.Push` and `Handlers.Pull` using existing `httpjson.WriteJSON` and `httpjson.WriteError`.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/sync`

Expected: sync package tests pass.

### Task 4: Server Wiring And Auth Protection

**Files:**
- Modify: `services/api/internal/server/server.go`
- Modify: `services/api/internal/server/server_test.go`

- [ ] **Step 1: Write failing server tests**

Add tests proving `/api/sync/push` rejects unauthenticated requests and works after registration with bearer token.

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/server`

Expected: sync route missing.

- [ ] **Step 3: Wire sync repository and routes**

Create one SQLite-backed sync repository in `New`, one memory sync repository in existing tests, and register authenticated sync handlers.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/server`

Expected: server tests pass.

### Task 5: API Docs And Full Verification

**Files:**
- Create: `docs/api/sync.md`
- Modify: `services/api/README.md`

- [ ] **Step 1: Document endpoints**

Document `POST /api/sync/push` and `GET /api/sync/pull?since=0` with auth header, request bodies, and responses.

- [ ] **Step 2: Run full backend tests**

Run: `go test -count=1 ./...`

Expected: all backend packages pass.

- [ ] **Step 3: Commit**

Commit message: `feat: 添加服务端笔记同步 API`

## Self Review

- Spec coverage: tasks cover domain model, SQLite persistence, HTTP API, auth wiring, docs, and tests.
- Placeholder scan: no deferred implementation scope remains inside this plan.
- Type consistency: plan uses `Folder`, `Note`, `PushInput`, `PushResult`, `PullResult`, and `Repository` consistently.
