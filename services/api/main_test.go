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
