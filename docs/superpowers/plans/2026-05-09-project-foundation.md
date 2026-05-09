# Project Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the repository foundation for a Flutter Windows/Android client and Go sync server, with Chinese UTF-8 documentation, fixed formatting rules, basic run instructions, and first-pass verification commands.

**Architecture:** The repository will be a monorepo with `apps/client` for Flutter and `services/api` for Go. Shared documentation lives in `docs/`, while generated runtime data, build outputs, and local environment files stay ignored by git. This plan intentionally avoids product features and only prepares the structure required by later feature plans.

**Tech Stack:** Flutter, Dart, Go, PowerShell, Git, Markdown, EditorConfig, Git attributes.

---

## File Structure

Create or modify these files and directories:

- Modify: `README.md` for project overview, setup, and current status.
- Create: `docs/development/code-style.md` for UTF-8, comments, commits, and branch conventions.
- Create: `docs/development/local-run.md` for local client/server run commands.
- Create: `apps/client/README.md` for Flutter client notes.
- Create: `services/api/README.md` for Go API service notes.
- Create: `services/api/go.mod` using module `github.com/lblgb/note/services/api`.
- Create: `services/api/main.go` as the minimal API service entry point.
- Create: `services/api/main_test.go` as the first Go verification test.
- Modify: `.gitignore` to include environment files and generated Flutter platform build outputs if missing.
- Modify: `.editorconfig` only if it does not already enforce UTF-8 and LF.
- Modify: `.gitattributes` only if it does not already normalize text files to LF.

Do not create the Flutter project in this foundation plan unless Flutter is installed locally and `flutter --version` succeeds. If Flutter is unavailable, create `apps/client/README.md` and leave actual Flutter scaffolding to the next client-specific plan.

### Task 1: Verify Current Repository Baseline

**Files:**
- Read: `.gitignore`
- Read: `.editorconfig`
- Read: `.gitattributes`
- Read: `docs/superpowers/specs/2026-05-09-note-app-design.md`

- [ ] **Step 1: Check git status**

Run:

```powershell
git status --short
```

Expected: no output. If output exists, inspect it and do not overwrite unrelated user changes.

- [ ] **Step 2: Check current branch and remote**

Run:

```powershell
git branch --show-current
git remote -v
```

Expected: current branch is `master`, and `origin` points to `https://github.com/lblgb/note.git`.

- [ ] **Step 3: Confirm foundation files already present**

Run:

```powershell
Get-Content -Raw .editorconfig
Get-Content -Raw .gitattributes
Get-Content -Raw .gitignore
```

Expected:

- `.editorconfig` contains `charset = utf-8` and `end_of_line = lf`.
- `.gitattributes` contains `* text=auto eol=lf`.
- `.gitignore` contains `.superpowers/`, `build/`, `data/`, and SQLite file patterns.

### Task 2: Add Root Project Documentation

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the root README**

Create `README.md` with this exact content:

```markdown
# 轻量多端同步笔记

> 文件说明：本文档介绍项目目标、目录结构、当前状态和本地开发入口。

本项目是一个本地优先的轻量多端同步笔记应用，计划覆盖 Windows 端和 Android 端。客户端使用 Flutter，后端使用 Go，自建同步服务负责账号、设备、笔记、附件和多端同步。

## 当前状态

当前仓库处于基础设计和工程骨架阶段。已完成第一版设计文档，尚未开始业务功能实现。

## 第一版目标

- 支持账号注册、登录和退出登录。
- 支持 Windows 和 Android 客户端。
- 支持文件夹、笔记、图片附件、外部链接和内部笔记链接。
- 支持本地离线编辑。
- 支持多端同步。
- 支持冲突副本，避免覆盖用户内容。

## 技术栈

- 客户端：Flutter、Dart、SQLite。
- 后端：Go、PostgreSQL。
- 附件：可插拔存储层，开发默认本地文件存储，生产可切换对象存储。
- 文档：中文 Markdown。

## 目录结构

```text
apps/
  client/                 Flutter 客户端
services/
  api/                    Go 同步后端
docs/
  development/            开发规范和本地运行说明
  superpowers/
    specs/                设计文档
    plans/                实现计划
```

## 编码与注释约束

- 所有文本和代码文件使用 UTF-8 编码。
- 文档使用中文。
- 代码相关文件开头添加简单文件说明注释。
- 每个方法或函数添加简单注释。
- 重要阶段提交 git，并推送到 GitHub。

## 设计文档

第一版设计文档位于：

```text
docs/superpowers/specs/2026-05-09-note-app-design.md
```

## 本地运行

本地运行方式见：

```text
docs/development/local-run.md
```
```

- [ ] **Step 2: Verify README exists**

Run:

```powershell
Test-Path README.md
```

Expected: `True`.

### Task 3: Add Development Documentation

**Files:**
- Create: `docs/development/code-style.md`
- Create: `docs/development/local-run.md`

- [ ] **Step 1: Create the development docs directory**

Run:

```powershell
New-Item -ItemType Directory -Force docs/development
```

Expected: directory exists.

- [ ] **Step 2: Write code style documentation**

Create `docs/development/code-style.md` with this exact content:

```markdown
# 开发规范

> 文件说明：本文档记录项目编码、注释、提交和文档维护规则。

## 编码

- 所有文本和代码文件使用 UTF-8 编码。
- Git 文本文件统一使用 LF 换行。
- 编辑器应遵循仓库根目录的 `.editorconfig`。

## 语言

- 文档、注释和提交说明优先使用中文。
- 公开 API 名称、代码标识符和协议字段使用英文，保持跨语言一致性。

## 注释

- 代码相关文件开头必须有简单文件说明注释。
- 每个方法或函数必须有简单注释，说明用途。
- 注释说明意图，不重复描述显而易见的语法。

## Git

- 每完成一个可验证阶段提交一次。
- 提交前运行对应测试或验证命令。
- 提交后需要推送到 GitHub。
- 不提交构建产物、本地数据库、附件数据和本地密钥。

## 文档

- 架构、同步规则、API、运行方式和重要决策都写入 `docs/`。
- 功能实现改变设计时，同步更新相关文档。
```

- [ ] **Step 3: Write local run documentation**

Create `docs/development/local-run.md` with this exact content:

```markdown
# 本地运行说明

> 文件说明：本文档记录客户端和后端的本地运行入口。

## 环境要求

- Git。
- Flutter，用于 Windows 和 Android 客户端。
- Go，用于同步后端。
- PostgreSQL，后续用于服务端主数据库。

## 检查工具

```powershell
git --version
flutter --version
go version
```

## 客户端

客户端目录：

```text
apps/client
```

Flutter 项目创建后，运行方式为：

```powershell
Set-Location apps/client
flutter pub get
flutter run -d windows
```

Android 运行方式为：

```powershell
Set-Location apps/client
flutter devices
flutter run -d <android-device-id>
```

## 后端

后端目录：

```text
services/api
```

基础服务运行方式为：

```powershell
Set-Location services/api
go test ./...
go run .
```

默认健康检查地址：

```text
http://localhost:8080/health
```
```

- [ ] **Step 4: Verify docs can be found**

Run:

```powershell
Test-Path docs/development/code-style.md
Test-Path docs/development/local-run.md
```

Expected: both commands print `True`.

### Task 4: Create Go API Foundation

**Files:**
- Create: `services/api/README.md`
- Create: `services/api/go.mod`
- Create: `services/api/main.go`
- Create: `services/api/main_test.go`

- [ ] **Step 1: Create API directory**

Run:

```powershell
New-Item -ItemType Directory -Force services/api
```

Expected: directory exists.

- [ ] **Step 2: Write service README**

Create `services/api/README.md` with this exact content:

```markdown
# Go 同步后端

> 文件说明：本文档说明 Go 同步后端的职责和本地运行方式。

本服务负责账号认证、设备登记、变更同步和附件上传下载。当前阶段只提供基础健康检查，后续计划逐步加入账号和同步功能。

## 本地运行

```powershell
go test ./...
go run .
```

## 健康检查

```text
GET /health
```

成功响应：

```json
{"status":"ok"}
```
```

- [ ] **Step 3: Write Go module file**

Create `services/api/go.mod` with this exact content:

```go
module github.com/lblgb/note/services/api

go 1.22
```

- [ ] **Step 4: Write the minimal API service**

Create `services/api/main.go` with this exact content:

```go
// 文件说明：同步后端服务入口，提供基础 HTTP 服务和健康检查。
package main

import (
	"encoding/json"
	"log"
	"net/http"
)

// healthResponse 表示健康检查接口的响应内容。
type healthResponse struct {
	Status string `json:"status"`
}

// healthHandler 返回服务健康状态。
func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(healthResponse{Status: "ok"})
}

// newServer 创建后端 HTTP 路由。
func newServer() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	return mux
}

// main 启动同步后端 HTTP 服务。
func main() {
	addr := ":8080"
	log.Printf("同步后端启动：%s", addr)
	if err := http.ListenAndServe(addr, newServer()); err != nil {
		log.Fatalf("同步后端退出：%v", err)
	}
}
```

- [ ] **Step 5: Write the first Go test**

Create `services/api/main_test.go` with this exact content:

```go
// 文件说明：同步后端基础 HTTP 服务测试。
package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestHealthHandlerOK 验证健康检查接口返回成功状态。
func TestHealthHandlerOK(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	newServer().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("期望状态码 %d，实际状态码 %d", http.StatusOK, rec.Code)
	}

	body := rec.Body.String()
	if body != "{\"status\":\"ok\"}\n" {
		t.Fatalf("期望响应体 %q，实际响应体 %q", "{\"status\":\"ok\"}\n", body)
	}
}

// TestHealthHandlerMethodNotAllowed 验证健康检查接口拒绝非 GET 请求。
func TestHealthHandlerMethodNotAllowed(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/health", nil)
	rec := httptest.NewRecorder()

	newServer().ServeHTTP(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("期望状态码 %d，实际状态码 %d", http.StatusMethodNotAllowed, rec.Code)
	}
}
```

- [ ] **Step 6: Run Go tests**

Run:

```powershell
Set-Location services/api
go test ./...
```

Expected: `ok github.com/lblgb/note/services/api`.

- [ ] **Step 7: Format Go files**

Run:

```powershell
Set-Location services/api
gofmt -w main.go main_test.go
go test ./...
```

Expected: tests pass.

### Task 5: Add Flutter Client Placeholder

**Files:**
- Create: `apps/client/README.md`

- [ ] **Step 1: Create client directory**

Run:

```powershell
New-Item -ItemType Directory -Force apps/client
```

Expected: directory exists.

- [ ] **Step 2: Check whether Flutter is installed**

Run:

```powershell
flutter --version
```

Expected if Flutter is installed: version details print successfully. If the command fails, do not scaffold Flutter yet.

- [ ] **Step 3: Write client README**

Create `apps/client/README.md` with this exact content:

```markdown
# Flutter 客户端

> 文件说明：本文档说明 Flutter 客户端的职责和本地运行入口。

客户端负责 Windows 和 Android 端的笔记编辑、文件夹管理、图片附件、外部链接、内部笔记链接、本地离线存储和同步状态展示。

## 当前状态

当前目录是客户端占位目录。Flutter 工程将在客户端基础计划中创建。

## 计划能力

- Windows 三栏布局。
- Android 分层导航布局。
- Markdown 编辑和预览。
- 图片附件插入和展示。
- 外部链接跳转。
- 内部笔记链接跳转。
- SQLite 本地数据层。
- 同步队列和同步状态。
```

- [ ] **Step 4: Verify client README exists**

Run:

```powershell
Test-Path apps/client/README.md
```

Expected: `True`.

### Task 6: Tighten Ignore Rules

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Ensure environment and generated files are ignored**

Update `.gitignore` so it contains these entries in addition to the existing entries:

```gitignore
# 本地环境配置
.env
.env.*
!.env.example

# 日志
*.log

# Android / Gradle
.gradle/

# Windows 构建产物
*.exe
*.dll
*.pdb
```

- [ ] **Step 2: Verify ignore rules**

Run:

```powershell
rg -n "\.env|\.gradle|\.exe|\.log" .gitignore
```

Expected: matching lines for `.env`, `.gradle/`, `*.exe`, and `*.log`.

### Task 7: Foundation Verification

**Files:**
- Read: all files changed in this plan.

- [ ] **Step 1: Scan for forbidden placeholders**

Run:

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]|以[后]再说" README.md docs apps services .gitignore .editorconfig .gitattributes
```

Expected: no output.

- [ ] **Step 2: Verify required Chinese file headers in docs**

Run:

```powershell
rg -n "文件说明" README.md docs apps services
```

Expected: each created Markdown file and Go file contains a file description or file comment.

- [ ] **Step 3: Verify Go tests**

Run:

```powershell
Set-Location services/api
go test ./...
```

Expected: all Go tests pass.

- [ ] **Step 4: Verify git status**

Run:

```powershell
git status --short
```

Expected: only intended foundation files are modified or created.

### Task 8: Commit and Push Foundation

**Files:**
- Commit all files changed by this foundation implementation.

- [ ] **Step 1: Stage foundation files**

Run:

```powershell
git add README.md docs/development/code-style.md docs/development/local-run.md apps/client/README.md services/api/README.md services/api/go.mod services/api/main.go services/api/main_test.go .gitignore
```

Expected: files are staged.

- [ ] **Step 2: Commit foundation**

Run:

```powershell
git commit -m "chore: 初始化项目基础结构"
```

Expected: commit succeeds.

- [ ] **Step 3: Push to GitHub**

Run:

```powershell
git push
```

Expected: local `master` pushes to `origin/master`.

---

## Self-Review

- Spec coverage: this plan covers repository structure, Chinese documentation, UTF-8/LF rules, code file comments, method comments for the initial Go code, local run docs, and git archive workflow.
- Intentional deferrals: account registration, Flutter app scaffolding, SQLite, sync protocol, attachments, and internal note links are covered by later dedicated plans.
- Placeholder scan: this plan avoids unresolved placeholder wording and unspecified implementation steps.
- Type consistency: Go symbols are consistently named `healthResponse`, `healthHandler`, `newServer`, `TestHealthHandlerOK`, and `TestHealthHandlerMethodNotAllowed`.
