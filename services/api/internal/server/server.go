// 文件说明：应用 HTTP 路由和鉴权中间件。
package server

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/lblgb/note/services/api/internal/auth"
	"github.com/lblgb/note/services/api/internal/httpjson"
	syncsvc "github.com/lblgb/note/services/api/internal/sync"
)

// New 创建完整应用 HTTP 服务。
func New() http.Handler {
	authRepo, err := auth.OpenSQLiteRepository(defaultAuthDatabasePath())
	if err != nil {
		log.Printf("打开 SQLite 认证仓库失败，回退到内存仓库：%v", err)
		authRepo = nil
	}
	syncRepo, err := syncsvc.OpenSQLiteRepository(defaultSyncDatabasePath())
	if err != nil {
		log.Printf("打开 SQLite 同步仓库失败，回退到内存仓库：%v", err)
		syncRepo = nil
	}
	if authRepo == nil {
		return NewWithRepositories(auth.NewMemoryRepository(), fallbackSyncRepository(syncRepo))
	}
	return NewWithRepositories(authRepo, fallbackSyncRepository(syncRepo))
}

// NewWithRepository 使用指定认证仓库创建完整应用 HTTP 服务。
func NewWithRepository(repo auth.Repository) http.Handler {
	return NewWithRepositories(repo, syncsvc.NewMemoryRepository())
}

// NewWithRepositories 使用指定认证仓库和同步仓库创建完整应用 HTTP 服务。
func NewWithRepositories(repo auth.Repository, syncRepo syncsvc.Repository) http.Handler {
	tokenManager := auth.NewTokenManager([]byte("dev-secret-change-before-production"), 15*time.Minute, 30*24*time.Hour)
	authService := auth.NewService(repo, tokenManager)
	authHandlers := auth.NewHandlers(authService)
	syncHandlers := syncsvc.NewHandlers(syncRepo)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/api/auth/register", authHandlers.Register)
	mux.HandleFunc("/api/auth/login", authHandlers.Login)
	mux.HandleFunc("/api/auth/refresh", authHandlers.Refresh)
	mux.HandleFunc("/api/auth/logout", authHandlers.Logout)
	mux.HandleFunc("/api/devices/register", requireAuth(authService, authHandlers.RegisterDevice))
	mux.HandleFunc("/api/sync/push", requireAuth(authService, syncHandlers.Push))
	mux.HandleFunc("/api/sync/pull", requireAuth(authService, syncHandlers.Pull))
	return mux
}

// defaultAuthDatabasePath 返回默认认证数据库路径。
func defaultAuthDatabasePath() string {
	if path := os.Getenv("NOTE_AUTH_DB"); path != "" {
		return path
	}
	return filepath.Join("data", "auth.db")
}

// defaultSyncDatabasePath 返回默认同步数据库路径。
func defaultSyncDatabasePath() string {
	if path := os.Getenv("NOTE_SYNC_DB"); path != "" {
		return path
	}
	return filepath.Join("data", "sync.db")
}

// fallbackSyncRepository 返回可用的同步仓库。
func fallbackSyncRepository(repo *syncsvc.SQLiteRepository) syncsvc.Repository {
	if repo == nil {
		return syncsvc.NewMemoryRepository()
	}
	return repo
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
