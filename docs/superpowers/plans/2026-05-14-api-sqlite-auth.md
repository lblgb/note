# API SQLite Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist Go API auth users, refresh sessions, and devices in SQLite.

**Architecture:** Add an `auth.SQLiteRepository` implementing the existing `auth.Repository` interface, keep `MemoryRepository` unchanged, and wire `server.New()` to open a default SQLite database. The HTTP handlers and service API stay unchanged.

**Tech Stack:** Go, `database/sql`, SQLite driver, existing auth service tests.

---

### Task 1: SQLite Repository

**Files:**
- Create: `services/api/internal/auth/sqlite_repository.go`
- Test: `services/api/internal/auth/sqlite_repository_test.go`

- [ ] Write failing tests for user persistence, refresh-session persistence, refresh rotation, and device save.
- [ ] Implement table creation, CRUD methods, and transaction logic.
- [ ] Run `go test ./internal/auth`.
- [ ] Commit SQLite repository.

### Task 2: Server Wiring

**Files:**
- Modify: `services/api/internal/server/server.go`
- Modify: `services/api/internal/server/server_test.go`
- Modify: `services/api/main.go`
- Modify: `services/api/README.md`

- [ ] Add `server.NewWithRepository(repo auth.Repository)` for tests.
- [ ] Make `server.New()` open `data/auth.db` by default.
- [ ] Keep tests using memory repository to avoid shared disk state.
- [ ] Document database path and persistence behavior.
- [ ] Run `go test ./...`.
- [ ] Commit server wiring.
