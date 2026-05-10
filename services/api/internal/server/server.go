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
