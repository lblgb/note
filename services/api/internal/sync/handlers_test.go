// 文件说明：测试同步 HTTP 处理器的请求解析和响应输出。
package sync

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestHandlersPush 验证推送接口写入同步数据并返回服务端版本。
func TestHandlersPush(t *testing.T) {
	repo := NewMemoryRepository()
	handlers := NewHandlers(repo)
	req := httptest.NewRequest(http.MethodPost, "/api/sync/push", strings.NewReader(`{
		"folders":[{"id":"fld_inbox","name":"收件箱","updatedAt":1770000000000000000}],
		"notes":[{"id":"note_1","folderId":"fld_inbox","title":"标题","body":"正文","updatedAt":1770000000000000001}]
	}`))
	rec := httptest.NewRecorder()

	handlers.Push(rec, req, "usr_1")

	if rec.Code != http.StatusOK {
		t.Fatalf("期望状态 200，实际为 %d，响应：%s", rec.Code, rec.Body.String())
	}
	var body PushResult
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("解析响应失败：%v", err)
	}
	if body.ServerVersion != 2 || body.Folders[0].ServerVersion != 1 || body.Notes[0].ServerVersion != 2 {
		t.Fatalf("版本响应不符合预期：%+v", body)
	}
}

// TestHandlersPushPreservesUpdatedAtFromJSON 验证 JSON updatedAt 会写入仓库。
func TestHandlersPushPreservesUpdatedAtFromJSON(t *testing.T) {
	repo := NewMemoryRepository()
	handlers := NewHandlers(repo)
	req := httptest.NewRequest(http.MethodPost, "/api/sync/push", strings.NewReader(`{
		"notes":[{"id":"note_1","title":"标题","body":"正文","updatedAt":1770000000000000001}]
	}`))
	rec := httptest.NewRecorder()

	handlers.Push(rec, req, "usr_1")
	if rec.Code != http.StatusOK {
		t.Fatalf("同步推送失败：%d %s", rec.Code, rec.Body.String())
	}
	pulled, err := repo.Pull(req.Context(), "usr_1", 0)
	if err != nil {
		t.Fatalf("拉取同步数据失败：%v", err)
	}
	if pulled.Notes[0].UpdatedAtNano != 1770000000000000001 {
		t.Fatalf("updatedAt 未按 JSON 保留：%+v", pulled.Notes[0])
	}
}

// TestHandlersPull 验证拉取接口按 since 返回同步数据。
func TestHandlersPull(t *testing.T) {
	repo := NewMemoryRepository()
	if _, err := repo.Push(httptest.NewRequest(http.MethodGet, "/", nil).Context(), "usr_1", PushInput{
		Notes: []Note{{ID: "note_1", Title: "标题", Body: "正文"}},
	}); err != nil {
		t.Fatalf("准备同步数据失败：%v", err)
	}
	handlers := NewHandlers(repo)
	req := httptest.NewRequest(http.MethodGet, "/api/sync/pull?since=0", nil)
	rec := httptest.NewRecorder()

	handlers.Pull(rec, req, "usr_1")

	if rec.Code != http.StatusOK {
		t.Fatalf("期望状态 200，实际为 %d，响应：%s", rec.Code, rec.Body.String())
	}
	var body PullResult
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("解析响应失败：%v", err)
	}
	if len(body.Notes) != 1 || body.Notes[0].ID != "note_1" {
		t.Fatalf("拉取响应不符合预期：%+v", body)
	}
}

// TestHandlersPushInvalidJSON 验证无效 JSON 返回 400。
func TestHandlersPushInvalidJSON(t *testing.T) {
	handlers := NewHandlers(NewMemoryRepository())
	req := httptest.NewRequest(http.MethodPost, "/api/sync/push", strings.NewReader(`{`))
	rec := httptest.NewRecorder()

	handlers.Push(rec, req, "usr_1")

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("期望状态 400，实际为 %d", rec.Code)
	}
}

// TestHandlersPullInvalidSince 验证无效 since 返回 400。
func TestHandlersPullInvalidSince(t *testing.T) {
	handlers := NewHandlers(NewMemoryRepository())
	req := httptest.NewRequest(http.MethodGet, "/api/sync/pull?since=bad", nil)
	rec := httptest.NewRecorder()

	handlers.Pull(rec, req, "usr_1")

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("期望状态 400，实际为 %d", rec.Code)
	}
}
