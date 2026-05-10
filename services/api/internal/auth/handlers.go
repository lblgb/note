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
	result, err := handlers.service.Register(r.Context(), RegisterInput{
		Email:       req.Email,
		Password:    req.Password,
		DisplayName: req.DisplayName,
	})
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
	result, err := handlers.service.Login(r.Context(), LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
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
	device, err := handlers.service.RegisterDevice(r.Context(), userID, DeviceInput{
		DeviceName: req.DeviceName,
		Platform:   req.Platform,
	})
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
