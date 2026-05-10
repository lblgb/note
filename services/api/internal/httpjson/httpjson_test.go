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
