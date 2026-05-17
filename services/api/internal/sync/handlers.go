// 文件说明：同步文件夹和笔记的 HTTP 处理器。
package sync

import (
	"net/http"
	"strconv"

	"github.com/lblgb/note/services/api/internal/httpjson"
)

// Handlers 提供同步相关 HTTP 入口。
type Handlers struct {
	repo Repository
}

// NewHandlers 创建同步处理器集合。
func NewHandlers(repo Repository) *Handlers {
	return &Handlers{repo: repo}
}

// Push 处理文件夹和笔记同步推送请求。
func (handlers *Handlers) Push(w http.ResponseWriter, r *http.Request, userID string) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	var input PushInput
	if err := httpjson.DecodeJSON(r, &input); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	result, err := handlers.repo.Push(r.Context(), userID, input)
	if err != nil {
		httpjson.WriteError(w, http.StatusInternalServerError, "internal_error", "服务内部错误")
		return
	}
	httpjson.WriteJSON(w, http.StatusOK, result)
}

// Pull 处理按服务端版本拉取文件夹和笔记变更请求。
func (handlers *Handlers) Pull(w http.ResponseWriter, r *http.Request, userID string) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	since, err := parseSince(r)
	if err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	result, err := handlers.repo.Pull(r.Context(), userID, since)
	if err != nil {
		httpjson.WriteError(w, http.StatusInternalServerError, "internal_error", "服务内部错误")
		return
	}
	httpjson.WriteJSON(w, http.StatusOK, result)
}

// parseSince 解析拉取请求中的 since 参数。
func parseSince(r *http.Request) (int64, error) {
	raw := r.URL.Query().Get("since")
	if raw == "" {
		return 0, nil
	}
	return strconv.ParseInt(raw, 10, 64)
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
