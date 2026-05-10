# API Auth Device Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Go backend foundation for account registration, login, access-token authentication, refresh-token rotation, and device registration.

**Architecture:** Keep the API service small and testable by splitting HTTP handlers, request/response types, auth logic, and in-memory repositories into focused packages. This stage uses an in-memory repository so auth and device behavior can be verified without PostgreSQL; later persistence work can replace the repository behind interfaces. Every endpoint returns JSON and uses the existing `net/http` server style.

**Tech Stack:** Go 1.22, standard `net/http`, `httptest`, `crypto/rand`, `crypto/hmac`, `crypto/sha256`, `golang.org/x/crypto/bcrypt`, JSON over HTTP.

---

## File Structure

Create or modify these files:

- Modify: `services/api/go.mod` to add `golang.org/x/crypto`.
- Modify: `services/api/main.go` to wire the application server instead of directly registering only `/health`.
- Create: `services/api/internal/httpjson/httpjson.go` for JSON response and request helpers.
- Create: `services/api/internal/auth/models.go` for user, device, token, and session models.
- Create: `services/api/internal/auth/repository.go` for repository interfaces and in-memory implementation.
- Create: `services/api/internal/auth/password.go` for password hashing and comparison.
- Create: `services/api/internal/auth/tokens.go` for signed access token and refresh token generation.
- Create: `services/api/internal/auth/service.go` for registration, login, refresh, logout, and device registration use cases.
- Create: `services/api/internal/auth/handlers.go` for auth and device HTTP handlers.
- Create: `services/api/internal/server/server.go` for route wiring and authentication middleware.
- Create: `services/api/internal/httpjson/httpjson_test.go`.
- Create: `services/api/internal/auth/password_test.go`.
- Create: `services/api/internal/auth/tokens_test.go`.
- Create: `services/api/internal/auth/service_test.go`.
- Create: `services/api/internal/auth/handlers_test.go`.
- Create: `services/api/internal/server/server_test.go`.
- Modify: `services/api/README.md` to document auth and device endpoints.
- Create: `docs/api/auth-device.md` to document request/response contracts.

Do not add PostgreSQL, migrations, Docker, note sync, attachments, or Flutter client calls in this plan.

## API Contract

All responses are JSON with `Content-Type: application/json; charset=utf-8`.

Error response shape:

```json
{"error":{"code":"invalid_request","message":"请求无效"}}
```

Endpoints:

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
POST /api/devices/register
GET  /health
```

Register request:

```json
{"email":"user@example.com","password":"pass123456","displayName":"用户"}
```

Register success response:

```json
{"user":{"id":"usr_...","email":"user@example.com","displayName":"用户"},"accessToken":"...","refreshToken":"..."}
```

Login request:

```json
{"email":"user@example.com","password":"pass123456"}
```

Refresh request:

```json
{"refreshToken":"..."}
```

Logout request:

```json
{"refreshToken":"..."}
```

Device registration requires `Authorization: Bearer <accessToken>`.

Device request:

```json
{"deviceName":"Windows 主力机","platform":"windows"}
```

Device success response:

```json
{"device":{"id":"dev_...","userId":"usr_...","deviceName":"Windows 主力机","platform":"windows"}}
```

### Task 1: JSON Helper Package

**Files:**
- Create: `services/api/internal/httpjson/httpjson.go`
- Create: `services/api/internal/httpjson/httpjson_test.go`

- [ ] **Step 1: Write failing tests for JSON helpers**

Create `services/api/internal/httpjson/httpjson_test.go`:

```go
// 文件说明：HTTP JSON 工具函数测试。
package httpjson

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestWriteJSON 验证 JSON 响应状态码、内容类型和响应体。
func TestWriteJSON(t *testing.T) {
	rec := httptest.NewRecorder()

	WriteJSON(rec, http.StatusCreated, map[string]string{"status": "ok"})

	if rec.Code != http.StatusCreated {
		t.Fatalf("期望状态码 %d，实际状态码 %d", http.StatusCreated, rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json; charset=utf-8" {
		t.Fatalf("期望 JSON 内容类型，实际为 %q", got)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"status":"ok"}` {
		t.Fatalf("期望响应体 %q，实际为 %q", `{"status":"ok"}`, got)
	}
}

// TestWriteError 验证统一错误响应结构。
func TestWriteError(t *testing.T) {
	rec := httptest.NewRecorder()

	WriteError(rec, http.StatusBadRequest, "invalid_request", "请求无效")

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("期望状态码 %d，实际状态码 %d", http.StatusBadRequest, rec.Code)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"error":{"code":"invalid_request","message":"请求无效"}}` {
		t.Fatalf("错误响应结构不匹配：%s", got)
	}
}

// TestDecodeJSON 验证请求体 JSON 解码。
func TestDecodeJSON(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{"name":"note"}`))
	var payload struct {
		Name string `json:"name"`
	}

	if err := DecodeJSON(req, &payload); err != nil {
		t.Fatalf("解码失败：%v", err)
	}
	if payload.Name != "note" {
		t.Fatalf("期望 name 为 note，实际为 %q", payload.Name)
	}
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/httpjson
```

Expected: fail because `WriteJSON`, `WriteError`, and `DecodeJSON` are undefined.

- [ ] **Step 3: Implement JSON helpers**

Create `services/api/internal/httpjson/httpjson.go`:

```go
// 文件说明：HTTP JSON 工具函数，统一请求解码和响应写入。
package httpjson

import (
	"encoding/json"
	"net/http"
)

// ErrorBody 表示统一错误响应结构。
type ErrorBody struct {
	Error ErrorDetail `json:"error"`
}

// ErrorDetail 表示错误编码和可展示消息。
type ErrorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// DecodeJSON 将请求体解析到目标结构体。
func DecodeJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(dst)
}

// WriteJSON 写入 JSON 响应。
func WriteJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// WriteError 写入统一错误响应。
func WriteError(w http.ResponseWriter, status int, code string, message string) {
	WriteJSON(w, status, ErrorBody{
		Error: ErrorDetail{Code: code, Message: message},
	})
}
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```powershell
Set-Location services/api
gofmt -w internal/httpjson/httpjson.go internal/httpjson/httpjson_test.go
go test ./internal/httpjson
```

Expected: tests pass.

- [ ] **Step 5: Commit JSON helpers**

Run:

```powershell
git add services/api/internal/httpjson/httpjson.go services/api/internal/httpjson/httpjson_test.go
git commit -m "feat: 添加 HTTP JSON 工具"
```

Expected: commit succeeds.

### Task 2: Auth Models And Repository

**Files:**
- Create: `services/api/internal/auth/models.go`
- Create: `services/api/internal/auth/repository.go`
- Create: `services/api/internal/auth/service_test.go`

- [ ] **Step 1: Write failing repository tests**

Create `services/api/internal/auth/service_test.go` with repository tests first:

```go
// 文件说明：认证服务和内存仓库测试。
package auth

import (
	"context"
	"testing"
)

// TestMemoryRepositoryCreateAndFindUser 验证用户创建和邮箱查询。
func TestMemoryRepositoryCreateAndFindUser(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", DisplayName: "用户", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}

	got, err := repo.FindUserByEmail(ctx, "USER@example.com")
	if err != nil {
		t.Fatalf("查询用户失败：%v", err)
	}
	if got.ID != user.ID {
		t.Fatalf("期望用户 ID %q，实际为 %q", user.ID, got.ID)
	}
}

// TestMemoryRepositoryRejectsDuplicateEmail 验证重复邮箱会被拒绝。
func TestMemoryRepositoryRejectsDuplicateEmail(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("首次创建用户失败：%v", err)
	}
	if err := repo.CreateUser(ctx, User{ID: "usr_other", Email: "USER@example.com"}); err != ErrEmailExists {
		t.Fatalf("期望 ErrEmailExists，实际为 %v", err)
	}
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/auth
```

Expected: fail because auth package types and repository functions are undefined.

- [ ] **Step 3: Implement models**

Create `services/api/internal/auth/models.go`:

```go
// 文件说明：认证领域模型，定义用户、设备、令牌和会话。
package auth

import "time"

// User 表示系统账号。
type User struct {
	ID           string
	Email        string
	DisplayName  string
	PasswordHash []byte
	CreatedAt    time.Time
}

// PublicUser 表示可以返回给客户端的用户信息。
type PublicUser struct {
	ID          string `json:"id"`
	Email       string `json:"email"`
	DisplayName string `json:"displayName"`
}

// Device 表示用户登录设备。
type Device struct {
	ID         string
	UserID     string
	DeviceName string
	Platform   string
	CreatedAt  time.Time
}

// PublicDevice 表示可以返回给客户端的设备信息。
type PublicDevice struct {
	ID         string `json:"id"`
	UserID     string `json:"userId"`
	DeviceName string `json:"deviceName"`
	Platform   string `json:"platform"`
}

// RefreshSession 表示刷新令牌会话。
type RefreshSession struct {
	TokenHash string
	UserID    string
	ExpiresAt time.Time
	Revoked   bool
}

// TokenPair 表示登录后的访问令牌和刷新令牌。
type TokenPair struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
}

// ToPublicUser 转换为客户端可见用户。
func ToPublicUser(user User) PublicUser {
	return PublicUser{ID: user.ID, Email: user.Email, DisplayName: user.DisplayName}
}

// ToPublicDevice 转换为客户端可见设备。
func ToPublicDevice(device Device) PublicDevice {
	return PublicDevice{ID: device.ID, UserID: device.UserID, DeviceName: device.DeviceName, Platform: device.Platform}
}
```

- [ ] **Step 4: Implement memory repository**

Create `services/api/internal/auth/repository.go`:

```go
// 文件说明：认证仓库接口和内存实现，后续可替换为 PostgreSQL 实现。
package auth

import (
	"context"
	"errors"
	"strings"
	"sync"
)

var (
	ErrEmailExists       = errors.New("email already exists")
	ErrUserNotFound      = errors.New("user not found")
	ErrSessionNotFound   = errors.New("refresh session not found")
	ErrDeviceNotFound    = errors.New("device not found")
)

// Repository 定义认证和设备数据访问能力。
type Repository interface {
	CreateUser(ctx context.Context, user User) error
	FindUserByEmail(ctx context.Context, email string) (User, error)
	FindUserByID(ctx context.Context, id string) (User, error)
	SaveRefreshSession(ctx context.Context, session RefreshSession) error
	FindRefreshSession(ctx context.Context, tokenHash string) (RefreshSession, error)
	RevokeRefreshSession(ctx context.Context, tokenHash string) error
	SaveDevice(ctx context.Context, device Device) error
}

// MemoryRepository 提供线程安全的内存仓库。
type MemoryRepository struct {
	mu       sync.RWMutex
	users    map[string]User
	emailIDs map[string]string
	sessions map[string]RefreshSession
	devices  map[string]Device
}

// NewMemoryRepository 创建内存仓库。
func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		users:    map[string]User{},
		emailIDs: map[string]string{},
		sessions: map[string]RefreshSession{},
		devices:  map[string]Device{},
	}
}

// CreateUser 保存新用户并拒绝重复邮箱。
func (repo *MemoryRepository) CreateUser(ctx context.Context, user User) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	email := normalizeEmail(user.Email)
	if _, exists := repo.emailIDs[email]; exists {
		return ErrEmailExists
	}
	repo.users[user.ID] = user
	repo.emailIDs[email] = user.ID
	return nil
}

// FindUserByEmail 按邮箱查询用户。
func (repo *MemoryRepository) FindUserByEmail(ctx context.Context, email string) (User, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	id, exists := repo.emailIDs[normalizeEmail(email)]
	if !exists {
		return User{}, ErrUserNotFound
	}
	return repo.users[id], nil
}

// FindUserByID 按 ID 查询用户。
func (repo *MemoryRepository) FindUserByID(ctx context.Context, id string) (User, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	user, exists := repo.users[id]
	if !exists {
		return User{}, ErrUserNotFound
	}
	return user, nil
}

// SaveRefreshSession 保存刷新令牌会话。
func (repo *MemoryRepository) SaveRefreshSession(ctx context.Context, session RefreshSession) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	repo.sessions[session.TokenHash] = session
	return nil
}

// FindRefreshSession 按令牌哈希查询刷新会话。
func (repo *MemoryRepository) FindRefreshSession(ctx context.Context, tokenHash string) (RefreshSession, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	session, exists := repo.sessions[tokenHash]
	if !exists {
		return RefreshSession{}, ErrSessionNotFound
	}
	return session, nil
}

// RevokeRefreshSession 撤销刷新令牌会话。
func (repo *MemoryRepository) RevokeRefreshSession(ctx context.Context, tokenHash string) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	session, exists := repo.sessions[tokenHash]
	if !exists {
		return ErrSessionNotFound
	}
	session.Revoked = true
	repo.sessions[tokenHash] = session
	return nil
}

// SaveDevice 保存用户设备。
func (repo *MemoryRepository) SaveDevice(ctx context.Context, device Device) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	repo.devices[device.ID] = device
	return nil
}

// normalizeEmail 统一邮箱大小写和空白。
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}
```

- [ ] **Step 5: Run repository tests**

Run:

```powershell
Set-Location services/api
gofmt -w internal/auth/models.go internal/auth/repository.go internal/auth/service_test.go
go test ./internal/auth
```

Expected: tests pass.

- [ ] **Step 6: Commit repository foundation**

Run:

```powershell
git add services/api/internal/auth/models.go services/api/internal/auth/repository.go services/api/internal/auth/service_test.go
git commit -m "feat: 添加认证内存仓库"
```

Expected: commit succeeds.

### Task 3: Password Hashing

**Files:**
- Create: `services/api/internal/auth/password.go`
- Create: `services/api/internal/auth/password_test.go`
- Modify: `services/api/go.mod`
- Modify: `services/api/go.sum`

- [ ] **Step 1: Write failing password tests**

Create `services/api/internal/auth/password_test.go`:

```go
// 文件说明：密码哈希和校验测试。
package auth

import "testing"

// TestHashAndComparePassword 验证密码哈希可以通过原密码校验。
func TestHashAndComparePassword(t *testing.T) {
	hash, err := HashPassword("pass123456")
	if err != nil {
		t.Fatalf("哈希密码失败：%v", err)
	}
	if len(hash) == 0 {
		t.Fatal("密码哈希不能为空")
	}
	if !ComparePassword(hash, "pass123456") {
		t.Fatal("原密码应通过校验")
	}
	if ComparePassword(hash, "wrong-password") {
		t.Fatal("错误密码不应通过校验")
	}
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/auth
```

Expected: fail because `HashPassword` and `ComparePassword` are undefined.

- [ ] **Step 3: Add bcrypt dependency**

Run:

```powershell
Set-Location services/api
go get golang.org/x/crypto/bcrypt
```

Expected: `go.mod` and `go.sum` update with `golang.org/x/crypto`.

- [ ] **Step 4: Implement password helpers**

Create `services/api/internal/auth/password.go`:

```go
// 文件说明：密码哈希和校验逻辑。
package auth

import "golang.org/x/crypto/bcrypt"

// HashPassword 生成安全密码哈希。
func HashPassword(password string) ([]byte, error) {
	return bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
}

// ComparePassword 校验明文密码是否匹配哈希。
func ComparePassword(hash []byte, password string) bool {
	return bcrypt.CompareHashAndPassword(hash, []byte(password)) == nil
}
```

- [ ] **Step 5: Run password tests**

Run:

```powershell
Set-Location services/api
gofmt -w internal/auth/password.go internal/auth/password_test.go
go test ./internal/auth
```

Expected: tests pass.

- [ ] **Step 6: Commit password helpers**

Run:

```powershell
git add services/api/go.mod services/api/go.sum services/api/internal/auth/password.go services/api/internal/auth/password_test.go
git commit -m "feat: 添加密码哈希校验"
```

Expected: commit succeeds.

### Task 4: Token Manager

**Files:**
- Create: `services/api/internal/auth/tokens.go`
- Create: `services/api/internal/auth/tokens_test.go`

- [ ] **Step 1: Write failing token tests**

Create `services/api/internal/auth/tokens_test.go`:

```go
// 文件说明：访问令牌和刷新令牌测试。
package auth

import (
	"testing"
	"time"
)

// TestAccessTokenRoundTrip 验证访问令牌签发和解析。
func TestAccessTokenRoundTrip(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)

	token, err := manager.IssueAccessToken("usr_test")
	if err != nil {
		t.Fatalf("签发访问令牌失败：%v", err)
	}
	claims, err := manager.ParseAccessToken(token)
	if err != nil {
		t.Fatalf("解析访问令牌失败：%v", err)
	}
	if claims.UserID != "usr_test" {
		t.Fatalf("期望用户 ID usr_test，实际为 %q", claims.UserID)
	}
}

// TestRefreshTokenAndHash 验证刷新令牌生成和哈希稳定性。
func TestRefreshTokenAndHash(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)

	token, hash, expiresAt, err := manager.IssueRefreshToken()
	if err != nil {
		t.Fatalf("签发刷新令牌失败：%v", err)
	}
	if token == "" || hash == "" {
		t.Fatal("刷新令牌和哈希不能为空")
	}
	if hash != manager.HashRefreshToken(token) {
		t.Fatal("刷新令牌哈希应稳定")
	}
	if !expiresAt.After(time.Now()) {
		t.Fatal("刷新令牌过期时间应在未来")
	}
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/auth
```

Expected: fail because `NewTokenManager` and token methods are undefined.

- [ ] **Step 3: Implement token manager**

Create `services/api/internal/auth/tokens.go`:

```go
// 文件说明：访问令牌和刷新令牌签发、校验逻辑。
package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

var ErrInvalidToken = errors.New("invalid token")

// AccessClaims 表示访问令牌载荷。
type AccessClaims struct {
	UserID    string `json:"userId"`
	ExpiresAt int64  `json:"expiresAt"`
}

// TokenManager 管理访问令牌和刷新令牌。
type TokenManager struct {
	secret        []byte
	accessTTL     time.Duration
	refreshTTL    time.Duration
}

// NewTokenManager 创建令牌管理器。
func NewTokenManager(secret []byte, accessTTL time.Duration, refreshTTL time.Duration) *TokenManager {
	return &TokenManager{secret: secret, accessTTL: accessTTL, refreshTTL: refreshTTL}
}

// IssueAccessToken 签发 HMAC 访问令牌。
func (manager *TokenManager) IssueAccessToken(userID string) (string, error) {
	claims := AccessClaims{UserID: userID, ExpiresAt: time.Now().Add(manager.accessTTL).Unix()}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	payloadText := base64.RawURLEncoding.EncodeToString(payload)
	signature := manager.sign(payloadText)
	return payloadText + "." + signature, nil
}

// ParseAccessToken 解析并验证访问令牌。
func (manager *TokenManager) ParseAccessToken(token string) (AccessClaims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return AccessClaims{}, ErrInvalidToken
	}
	if !hmac.Equal([]byte(manager.sign(parts[0])), []byte(parts[1])) {
		return AccessClaims{}, ErrInvalidToken
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return AccessClaims{}, ErrInvalidToken
	}
	var claims AccessClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return AccessClaims{}, ErrInvalidToken
	}
	if time.Now().Unix() >= claims.ExpiresAt {
		return AccessClaims{}, ErrInvalidToken
	}
	return claims, nil
}

// IssueRefreshToken 生成刷新令牌、哈希和过期时间。
func (manager *TokenManager) IssueRefreshToken() (string, string, time.Time, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", "", time.Time{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	return token, manager.HashRefreshToken(token), time.Now().Add(manager.refreshTTL), nil
}

// HashRefreshToken 生成刷新令牌服务端存储哈希。
func (manager *TokenManager) HashRefreshToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// sign 生成载荷签名。
func (manager *TokenManager) sign(payload string) string {
	mac := hmac.New(sha256.New, manager.secret)
	_, _ = mac.Write([]byte(payload))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
```

- [ ] **Step 4: Run token tests**

Run:

```powershell
Set-Location services/api
gofmt -w internal/auth/tokens.go internal/auth/tokens_test.go
go test ./internal/auth
```

Expected: tests pass.

- [ ] **Step 5: Commit token manager**

Run:

```powershell
git add services/api/internal/auth/tokens.go services/api/internal/auth/tokens_test.go
git commit -m "feat: 添加认证令牌管理"
```

Expected: commit succeeds.

### Task 5: Auth Service Use Cases

**Files:**
- Create: `services/api/internal/auth/service.go`
- Modify: `services/api/internal/auth/service_test.go`

- [ ] **Step 1: Add failing service tests**

Append these tests to `services/api/internal/auth/service_test.go`:

```go
// TestServiceRegisterLoginRefreshLogout 验证注册、登录、刷新和退出流程。
func TestServiceRegisterLoginRefreshLogout(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	ctx := context.Background()

	registered, err := service.Register(ctx, RegisterInput{Email: "user@example.com", Password: "pass123456", DisplayName: "用户"})
	if err != nil {
		t.Fatalf("注册失败：%v", err)
	}
	if registered.User.Email != "user@example.com" || registered.AccessToken == "" || registered.RefreshToken == "" {
		t.Fatalf("注册响应不完整：%+v", registered)
	}

	loggedIn, err := service.Login(ctx, LoginInput{Email: "user@example.com", Password: "pass123456"})
	if err != nil {
		t.Fatalf("登录失败：%v", err)
	}
	if loggedIn.AccessToken == "" || loggedIn.RefreshToken == "" {
		t.Fatalf("登录令牌不能为空：%+v", loggedIn)
	}

	refreshed, err := service.Refresh(ctx, loggedIn.RefreshToken)
	if err != nil {
		t.Fatalf("刷新失败：%v", err)
	}
	if refreshed.AccessToken == "" || refreshed.RefreshToken == "" || refreshed.RefreshToken == loggedIn.RefreshToken {
		t.Fatalf("刷新应返回新令牌：%+v", refreshed)
	}

	if err := service.Logout(ctx, refreshed.RefreshToken); err != nil {
		t.Fatalf("退出登录失败：%v", err)
	}
	if _, err := service.Refresh(ctx, refreshed.RefreshToken); err != ErrInvalidCredentials {
		t.Fatalf("已退出刷新令牌应失效，实际错误：%v", err)
	}
}

// TestServiceRegisterRejectsWeakPassword 验证弱密码被拒绝。
func TestServiceRegisterRejectsWeakPassword(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))

	_, err := service.Register(context.Background(), RegisterInput{Email: "user@example.com", Password: "short", DisplayName: "用户"})
	if err != ErrInvalidInput {
		t.Fatalf("期望 ErrInvalidInput，实际为 %v", err)
	}
}

// TestServiceRegisterDevice 验证设备登记。
func TestServiceRegisterDevice(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	ctx := context.Background()

	registered, err := service.Register(ctx, RegisterInput{Email: "user@example.com", Password: "pass123456", DisplayName: "用户"})
	if err != nil {
		t.Fatalf("注册失败：%v", err)
	}

	device, err := service.RegisterDevice(ctx, registered.User.ID, DeviceInput{DeviceName: "Windows 主力机", Platform: "windows"})
	if err != nil {
		t.Fatalf("设备登记失败：%v", err)
	}
	if device.UserID != registered.User.ID || device.Platform != "windows" {
		t.Fatalf("设备信息不匹配：%+v", device)
	}
}
```

- [ ] **Step 2: Add missing imports in service test**

Modify import block in `services/api/internal/auth/service_test.go`:

```go
import (
	"context"
	"testing"
	"time"
)
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/auth
```

Expected: fail because `Service`, input types, and use-case methods are undefined.

- [ ] **Step 4: Implement auth service**

Create `services/api/internal/auth/service.go`:

```go
// 文件说明：认证和设备登记用例服务。
package auth

import (
	"context"
	"errors"
	"strings"
	"time"
)

var (
	ErrInvalidInput       = errors.New("invalid input")
	ErrInvalidCredentials = errors.New("invalid credentials")
)

// Service 组合认证仓库和令牌管理器。
type Service struct {
	repo   Repository
	tokens *TokenManager
}

// RegisterInput 表示注册输入。
type RegisterInput struct {
	Email       string
	Password    string
	DisplayName string
}

// LoginInput 表示登录输入。
type LoginInput struct {
	Email    string
	Password string
}

// DeviceInput 表示设备登记输入。
type DeviceInput struct {
	DeviceName string
	Platform   string
}

// AuthResult 表示认证接口结果。
type AuthResult struct {
	User         PublicUser `json:"user"`
	AccessToken  string     `json:"accessToken"`
	RefreshToken string     `json:"refreshToken"`
}

// NewService 创建认证服务。
func NewService(repo Repository, tokens *TokenManager) *Service {
	return &Service{repo: repo, tokens: tokens}
}

// Register 注册新用户并返回令牌。
func (service *Service) Register(ctx context.Context, input RegisterInput) (AuthResult, error) {
	email := normalizeEmail(input.Email)
	if email == "" || len(input.Password) < 8 {
		return AuthResult{}, ErrInvalidInput
	}
	hash, err := HashPassword(input.Password)
	if err != nil {
		return AuthResult{}, err
	}
	user := User{
		ID:           newID("usr"),
		Email:        email,
		DisplayName:  strings.TrimSpace(input.DisplayName),
		PasswordHash: hash,
		CreatedAt:    time.Now(),
	}
	if err := service.repo.CreateUser(ctx, user); err != nil {
		return AuthResult{}, err
	}
	return service.issueAuthResult(ctx, user)
}

// Login 校验账号密码并返回令牌。
func (service *Service) Login(ctx context.Context, input LoginInput) (AuthResult, error) {
	user, err := service.repo.FindUserByEmail(ctx, input.Email)
	if err != nil {
		return AuthResult{}, ErrInvalidCredentials
	}
	if !ComparePassword(user.PasswordHash, input.Password) {
		return AuthResult{}, ErrInvalidCredentials
	}
	return service.issueAuthResult(ctx, user)
}

// Refresh 轮换刷新令牌并返回新令牌。
func (service *Service) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	hash := service.tokens.HashRefreshToken(refreshToken)
	session, err := service.repo.FindRefreshSession(ctx, hash)
	if err != nil || session.Revoked || time.Now().After(session.ExpiresAt) {
		return TokenPair{}, ErrInvalidCredentials
	}
	if err := service.repo.RevokeRefreshSession(ctx, hash); err != nil {
		return TokenPair{}, err
	}
	return service.issueTokenPair(ctx, session.UserID)
}

// Logout 撤销刷新令牌。
func (service *Service) Logout(ctx context.Context, refreshToken string) error {
	hash := service.tokens.HashRefreshToken(refreshToken)
	if err := service.repo.RevokeRefreshSession(ctx, hash); err != nil {
		return ErrInvalidCredentials
	}
	return nil
}

// RegisterDevice 登记当前用户设备。
func (service *Service) RegisterDevice(ctx context.Context, userID string, input DeviceInput) (PublicDevice, error) {
	if strings.TrimSpace(input.DeviceName) == "" || strings.TrimSpace(input.Platform) == "" {
		return PublicDevice{}, ErrInvalidInput
	}
	device := Device{
		ID:         newID("dev"),
		UserID:     userID,
		DeviceName: strings.TrimSpace(input.DeviceName),
		Platform:   strings.TrimSpace(input.Platform),
		CreatedAt:  time.Now(),
	}
	if err := service.repo.SaveDevice(ctx, device); err != nil {
		return PublicDevice{}, err
	}
	return ToPublicDevice(device), nil
}

// ParseAccessToken 解析访问令牌。
func (service *Service) ParseAccessToken(token string) (AccessClaims, error) {
	return service.tokens.ParseAccessToken(token)
}

// issueAuthResult 生成认证结果。
func (service *Service) issueAuthResult(ctx context.Context, user User) (AuthResult, error) {
	pair, err := service.issueTokenPair(ctx, user.ID)
	if err != nil {
		return AuthResult{}, err
	}
	return AuthResult{User: ToPublicUser(user), AccessToken: pair.AccessToken, RefreshToken: pair.RefreshToken}, nil
}

// issueTokenPair 生成访问令牌和刷新令牌。
func (service *Service) issueTokenPair(ctx context.Context, userID string) (TokenPair, error) {
	accessToken, err := service.tokens.IssueAccessToken(userID)
	if err != nil {
		return TokenPair{}, err
	}
	refreshToken, refreshHash, expiresAt, err := service.tokens.IssueRefreshToken()
	if err != nil {
		return TokenPair{}, err
	}
	if err := service.repo.SaveRefreshSession(ctx, RefreshSession{TokenHash: refreshHash, UserID: userID, ExpiresAt: expiresAt}); err != nil {
		return TokenPair{}, err
	}
	return TokenPair{AccessToken: accessToken, RefreshToken: refreshToken}, nil
}

// newID 生成带前缀的随机 ID。
func newID(prefix string) string {
	token := time.Now().UnixNano()
	return prefix + "_" + strings.TrimLeft(strings.ReplaceAll(time.Unix(0, token).Format("20060102150405.000000000"), ".", ""), "0")
}
```

- [ ] **Step 5: Run service tests**

Run:

```powershell
Set-Location services/api
gofmt -w internal/auth/service.go internal/auth/service_test.go
go test ./internal/auth
```

Expected: tests pass.

- [ ] **Step 6: Commit auth service**

Run:

```powershell
git add services/api/internal/auth/service.go services/api/internal/auth/service_test.go
git commit -m "feat: 添加认证服务用例"
```

Expected: commit succeeds.

### Task 6: HTTP Handlers

**Files:**
- Create: `services/api/internal/auth/handlers.go`
- Create: `services/api/internal/auth/handlers_test.go`

- [ ] **Step 1: Write failing handler tests**

Create `services/api/internal/auth/handlers_test.go`:

```go
// 文件说明：认证和设备 HTTP 处理器测试。
package auth

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// TestHandlersRegisterLoginAndDevice 验证注册、登录和设备登记 HTTP 流程。
func TestHandlersRegisterLoginAndDevice(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	handlers := NewHandlers(service)

	registerReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", strings.NewReader(`{"email":"user@example.com","password":"pass123456","displayName":"用户"}`))
	registerRec := httptest.NewRecorder()
	handlers.Register(registerRec, registerReq)
	if registerRec.Code != http.StatusCreated {
		t.Fatalf("注册状态码应为 201，实际为 %d，响应为 %s", registerRec.Code, registerRec.Body.String())
	}

	loginReq := httptest.NewRequest(http.MethodPost, "/api/auth/login", strings.NewReader(`{"email":"user@example.com","password":"pass123456"}`))
	loginRec := httptest.NewRecorder()
	handlers.Login(loginRec, loginReq)
	if loginRec.Code != http.StatusOK {
		t.Fatalf("登录状态码应为 200，实际为 %d，响应为 %s", loginRec.Code, loginRec.Body.String())
	}
}

// TestHandlersRejectWrongMethod 验证错误方法被拒绝。
func TestHandlersRejectWrongMethod(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	handlers := NewHandlers(service)

	req := httptest.NewRequest(http.MethodGet, "/api/auth/login", nil)
	rec := httptest.NewRecorder()
	handlers.Login(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("期望 405，实际为 %d", rec.Code)
	}
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/auth
```

Expected: fail because `NewHandlers` and handler methods are undefined.

- [ ] **Step 3: Implement HTTP handlers**

Create `services/api/internal/auth/handlers.go`:

```go
// 文件说明：认证和设备登记 HTTP 处理器。
package auth

import (
	"errors"
	"net/http"

	"github.com/lblgb/note/services/api/internal/httpjson"
)

// Handlers 提供认证相关 HTTP 入口。
type Handlers struct {
	service *Service
}

// NewHandlers 创建认证处理器集合。
func NewHandlers(service *Service) *Handlers {
	return &Handlers{service: service}
}

// Register 处理账号注册请求。
func (handlers *Handlers) Register(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"displayName"`
	}
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	result, err := handlers.service.Register(r.Context(), RegisterInput(req))
	writeAuthResult(w, result, err, http.StatusCreated)
}

// Login 处理账号登录请求。
func (handlers *Handlers) Login(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	result, err := handlers.service.Login(r.Context(), LoginInput(req))
	writeAuthResult(w, result, err, http.StatusOK)
}

// Refresh 处理刷新令牌请求。
func (handlers *Handlers) Refresh(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	result, err := handlers.service.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	httpjson.WriteJSON(w, http.StatusOK, result)
}

// Logout 处理退出登录请求。
func (handlers *Handlers) Logout(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	if err := handlers.service.Logout(r.Context(), req.RefreshToken); err != nil {
		writeServiceError(w, err)
		return
	}
	httpjson.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// RegisterDevice 处理设备登记请求。
func (handlers *Handlers) RegisterDevice(w http.ResponseWriter, r *http.Request, userID string) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var req struct {
		DeviceName string `json:"deviceName"`
		Platform   string `json:"platform"`
	}
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	device, err := handlers.service.RegisterDevice(r.Context(), userID, DeviceInput(req))
	if err != nil {
		writeServiceError(w, err)
		return
	}
	httpjson.WriteJSON(w, http.StatusCreated, map[string]PublicDevice{"device": device})
}

// requireMethod 限制 HTTP 方法。
func requireMethod(w http.ResponseWriter, r *http.Request, method string) bool {
	if r.Method == method {
		return true
	}
	w.Header().Set("Allow", method)
	httpjson.WriteError(w, http.StatusMethodNotAllowed, "method_not_allowed", "请求方法不允许")
	return false
}

// writeAuthResult 写入认证结果或错误。
func writeAuthResult(w http.ResponseWriter, result AuthResult, err error, status int) {
	if err != nil {
		writeServiceError(w, err)
		return
	}
	httpjson.WriteJSON(w, status, result)
}

// writeServiceError 将服务错误映射为 HTTP 错误。
func writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrInvalidInput):
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
	case errors.Is(err, ErrEmailExists):
		httpjson.WriteError(w, http.StatusConflict, "email_exists", "邮箱已注册")
	case errors.Is(err, ErrInvalidCredentials):
		httpjson.WriteError(w, http.StatusUnauthorized, "invalid_credentials", "账号或凭据无效")
	default:
		httpjson.WriteError(w, http.StatusInternalServerError, "internal_error", "服务内部错误")
	}
}
```

- [ ] **Step 4: Run handler tests**

Run:

```powershell
Set-Location services/api
gofmt -w internal/auth/handlers.go internal/auth/handlers_test.go
go test ./internal/auth
```

Expected: tests pass.

- [ ] **Step 5: Commit HTTP handlers**

Run:

```powershell
git add services/api/internal/auth/handlers.go services/api/internal/auth/handlers_test.go
git commit -m "feat: 添加认证 HTTP 处理器"
```

Expected: commit succeeds.

### Task 7: Server Wiring And Auth Middleware

**Files:**
- Create: `services/api/internal/server/server.go`
- Create: `services/api/internal/server/server_test.go`
- Modify: `services/api/main.go`
- Modify: `services/api/main_test.go`

- [ ] **Step 1: Write failing server tests**

Create `services/api/internal/server/server_test.go`:

```go
// 文件说明：应用路由和鉴权中间件测试。
package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestServerAuthAndDeviceFlow 验证注册后携带访问令牌登记设备。
func TestServerAuthAndDeviceFlow(t *testing.T) {
	handler := New()

	registerReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", strings.NewReader(`{"email":"user@example.com","password":"pass123456","displayName":"用户"}`))
	registerRec := httptest.NewRecorder()
	handler.ServeHTTP(registerRec, registerReq)
	if registerRec.Code != http.StatusCreated {
		t.Fatalf("注册失败：%d %s", registerRec.Code, registerRec.Body.String())
	}
	var authResp struct {
		AccessToken string `json:"accessToken"`
	}
	if err := json.Unmarshal(registerRec.Body.Bytes(), &authResp); err != nil {
		t.Fatalf("解析注册响应失败：%v", err)
	}

	deviceReq := httptest.NewRequest(http.MethodPost, "/api/devices/register", strings.NewReader(`{"deviceName":"Windows 主力机","platform":"windows"}`))
	deviceReq.Header.Set("Authorization", "Bearer "+authResp.AccessToken)
	deviceRec := httptest.NewRecorder()
	handler.ServeHTTP(deviceRec, deviceReq)
	if deviceRec.Code != http.StatusCreated {
		t.Fatalf("设备登记失败：%d %s", deviceRec.Code, deviceRec.Body.String())
	}
}

// TestServerDeviceRequiresAuth 验证设备登记要求访问令牌。
func TestServerDeviceRequiresAuth(t *testing.T) {
	handler := New()

	req := httptest.NewRequest(http.MethodPost, "/api/devices/register", strings.NewReader(`{"deviceName":"Windows 主力机","platform":"windows"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("未授权请求期望 401，实际为 %d", rec.Code)
	}
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location services/api
go test ./internal/server
```

Expected: fail because `server.New` is undefined.

- [ ] **Step 3: Implement server wiring**

Create `services/api/internal/server/server.go`:

```go
// 文件说明：应用 HTTP 路由和鉴权中间件。
package server

import (
	"net/http"
	"strings"
	"time"

	"github.com/lblgb/note/services/api/internal/auth"
	"github.com/lblgb/note/services/api/internal/httpjson"
)

// New 创建完整应用 HTTP 服务。
func New() http.Handler {
	repo := auth.NewMemoryRepository()
	tokenManager := auth.NewTokenManager([]byte("dev-secret-change-before-production"), 15*time.Minute, 30*24*time.Hour)
	authService := auth.NewService(repo, tokenManager)
	authHandlers := auth.NewHandlers(authService)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/api/auth/register", authHandlers.Register)
	mux.HandleFunc("/api/auth/login", authHandlers.Login)
	mux.HandleFunc("/api/auth/refresh", authHandlers.Refresh)
	mux.HandleFunc("/api/auth/logout", authHandlers.Logout)
	mux.HandleFunc("/api/devices/register", requireAuth(authService, authHandlers.RegisterDevice))
	return mux
}

// healthHandler 返回服务健康状态。
func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", http.MethodGet)
		httpjson.WriteError(w, http.StatusMethodNotAllowed, "method_not_allowed", "请求方法不允许")
		return
	}
	httpjson.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// authenticatedHandler 表示需要用户 ID 的处理器。
type authenticatedHandler func(http.ResponseWriter, *http.Request, string)

// requireAuth 校验 Bearer 访问令牌。
func requireAuth(service *auth.Service, next authenticatedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			httpjson.WriteError(w, http.StatusUnauthorized, "unauthorized", "未登录或令牌无效")
			return
		}
		claims, err := service.ParseAccessToken(strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			httpjson.WriteError(w, http.StatusUnauthorized, "unauthorized", "未登录或令牌无效")
			return
		}
		next(w, r, claims.UserID)
	}
}
```

- [ ] **Step 4: Update main entrypoint**

Modify `services/api/main.go`:

```go
// 文件说明：同步后端服务入口，启动应用 HTTP 服务。
package main

import (
	"log"
	"net/http"

	"github.com/lblgb/note/services/api/internal/server"
)

// main 启动同步后端 HTTP 服务。
func main() {
	addr := ":8080"
	log.Printf("同步后端启动：%s", addr)
	if err := http.ListenAndServe(addr, server.New()); err != nil {
		log.Fatalf("同步后端退出：%v", err)
	}
}
```

- [ ] **Step 5: Update root main tests**

Modify `services/api/main_test.go`:

```go
// 文件说明：同步后端基础 HTTP 服务测试。
package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/lblgb/note/services/api/internal/server"
)

// TestHealthHandlerOK 验证健康检查接口返回成功状态。
func TestHealthHandlerOK(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	server.New().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("期望状态码 %d，实际状态码 %d", http.StatusOK, rec.Code)
	}

	body := strings.TrimSpace(rec.Body.String())
	if body != `{"status":"ok"}` {
		t.Fatalf("期望响应体 %q，实际响应体 %q", `{"status":"ok"}`, body)
	}
}

// TestHealthHandlerMethodNotAllowed 验证健康检查接口拒绝非 GET 请求。
func TestHealthHandlerMethodNotAllowed(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/health", nil)
	rec := httptest.NewRecorder()

	server.New().ServeHTTP(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("期望状态码 %d，实际状态码 %d", http.StatusMethodNotAllowed, rec.Code)
	}
}
```

- [ ] **Step 6: Run server tests**

Run:

```powershell
Set-Location services/api
gofmt -w main.go main_test.go internal/server/server.go internal/server/server_test.go
go test ./...
```

Expected: all tests pass.

- [ ] **Step 7: Commit server wiring**

Run:

```powershell
git add services/api/main.go services/api/main_test.go services/api/internal/server/server.go services/api/internal/server/server_test.go
git commit -m "feat: 接入认证路由和设备鉴权"
```

Expected: commit succeeds.

### Task 8: API Documentation

**Files:**
- Modify: `services/api/README.md`
- Create: `docs/api/auth-device.md`

- [ ] **Step 1: Write API contract document**

Create `docs/api/auth-device.md`:

```markdown
# 账号认证与设备 API

> 文件说明：本文档记录账号注册、登录、刷新令牌、退出登录和设备登记接口。

## 通用约定

- 请求和响应使用 JSON。
- 响应内容类型为 `application/json; charset=utf-8`。
- 设备登记接口需要 `Authorization: Bearer <accessToken>`。

## 错误结构

```json
{"error":{"code":"invalid_request","message":"请求无效"}}
```

## 注册

```text
POST /api/auth/register
```

请求：

```json
{"email":"user@example.com","password":"pass123456","displayName":"用户"}
```

成功响应：

```json
{"user":{"id":"usr_...","email":"user@example.com","displayName":"用户"},"accessToken":"...","refreshToken":"..."}
```

## 登录

```text
POST /api/auth/login
```

请求：

```json
{"email":"user@example.com","password":"pass123456"}
```

成功响应与注册一致。

## 刷新令牌

```text
POST /api/auth/refresh
```

请求：

```json
{"refreshToken":"..."}
```

成功响应：

```json
{"accessToken":"...","refreshToken":"..."}
```

## 退出登录

```text
POST /api/auth/logout
```

请求：

```json
{"refreshToken":"..."}
```

成功响应：

```json
{"status":"ok"}
```

## 设备登记

```text
POST /api/devices/register
```

请求头：

```text
Authorization: Bearer <accessToken>
```

请求：

```json
{"deviceName":"Windows 主力机","platform":"windows"}
```

成功响应：

```json
{"device":{"id":"dev_...","userId":"usr_...","deviceName":"Windows 主力机","platform":"windows"}}
```
```

- [ ] **Step 2: Update service README**

Modify `services/api/README.md`:

```markdown
# Go 同步后端

> 文件说明：本文档说明 Go 同步后端的职责和本地运行方式。

本服务负责账号认证、设备登记、变更同步和附件上传下载。当前阶段提供健康检查、账号注册、登录、刷新令牌、退出登录和设备登记。

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

## 账号与设备接口

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
POST /api/devices/register
```

详细接口文档见：

```text
docs/api/auth-device.md
```
```

- [ ] **Step 3: Verify docs**

Run:

```powershell
Test-Path docs/api/auth-device.md
rg -n "POST /api/auth/register|POST /api/devices/register" docs/api/auth-device.md services/api/README.md
```

Expected: path exists and endpoint references are found.

- [ ] **Step 4: Commit API docs**

Run:

```powershell
git add docs/api/auth-device.md services/api/README.md
git commit -m "docs: 添加认证和设备接口文档"
```

Expected: commit succeeds.

### Task 9: Full Verification And Push

**Files:**
- Read all files changed by this plan.

- [ ] **Step 1: Run full Go tests**

Run:

```powershell
Set-Location services/api
go test -count=1 ./...
```

Expected: all tests pass.

- [ ] **Step 2: Verify formatting**

Run:

```powershell
Set-Location services/api
gofmt -l main.go main_test.go internal/auth/*.go internal/httpjson/*.go internal/server/*.go
```

Expected: no output.

- [ ] **Step 3: Scan for unresolved placeholders**

Run:

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]|以[后]再说" services/api docs/api docs/superpowers/plans/2026-05-10-api-auth-device.md
```

Expected: no output.

- [ ] **Step 4: Verify file comments**

Run:

```powershell
rg -n "文件说明" services/api docs/api
```

Expected: every new Go and Markdown file has a file description comment or line.

- [ ] **Step 5: Verify git status**

Run:

```powershell
git status --short
```

Expected: no output after all task commits.

- [ ] **Step 6: Push branch**

Run:

```powershell
git push
```

Expected: current branch pushes to its upstream. If this plan is executed from a new feature branch, use `git push -u origin <branch-name>`.

---

## Self-Review

- Spec coverage: this plan covers registration, login, refresh-token rotation, logout, device registration, access-token authentication, endpoint documentation, tests, comments, and git commits.
- Intentional deferrals: PostgreSQL persistence, migrations, sync push/pull, note data, attachments, production secret management, rate limiting, and Flutter calls are excluded from this plan.
- Placeholder scan: this plan avoids unresolved placeholder wording and gives exact files, commands, code, and expected results.
- Type consistency: `Service`, `Repository`, `TokenManager`, `Handlers`, `RegisterInput`, `LoginInput`, `DeviceInput`, `AuthResult`, `TokenPair`, `PublicUser`, and `PublicDevice` are named consistently across tasks.
