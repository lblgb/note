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
