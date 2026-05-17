// 文件说明：应用路由和鉴权中间件测试。
package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/lblgb/note/services/api/internal/auth"
	syncsvc "github.com/lblgb/note/services/api/internal/sync"
)

// TestServerAuthAndDeviceFlow 验证注册后携带访问令牌登记设备。
func TestServerAuthAndDeviceFlow(t *testing.T) {
	handler := NewWithRepositories(auth.NewMemoryRepository(), syncsvc.NewMemoryRepository())

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
	handler := NewWithRepositories(auth.NewMemoryRepository(), syncsvc.NewMemoryRepository())

	req := httptest.NewRequest(http.MethodPost, "/api/devices/register", strings.NewReader(`{"deviceName":"Windows 主力机","platform":"windows"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("未授权请求期望 401，实际为 %d", rec.Code)
	}
}

// TestServerSyncRequiresAuth 验证同步推送要求访问令牌。
func TestServerSyncRequiresAuth(t *testing.T) {
	handler := NewWithRepositories(auth.NewMemoryRepository(), syncsvc.NewMemoryRepository())

	req := httptest.NewRequest(http.MethodPost, "/api/sync/push", strings.NewReader(`{"notes":[],"folders":[]}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("未授权同步请求期望 401，实际为 %d", rec.Code)
	}
}

// TestServerSyncPushAndPull 验证登录后可推送并拉取同步数据。
func TestServerSyncPushAndPull(t *testing.T) {
	handler := NewWithRepositories(auth.NewMemoryRepository(), syncsvc.NewMemoryRepository())
	token := registerAndReturnAccessToken(t, handler)

	pushReq := httptest.NewRequest(http.MethodPost, "/api/sync/push", strings.NewReader(`{
		"folders":[{"id":"fld_inbox","name":"收件箱","updatedAt":1770000000000000000}],
		"notes":[{"id":"note_1","folderId":"fld_inbox","title":"标题","body":"正文","updatedAt":1770000000000000001}]
	}`))
	pushReq.Header.Set("Authorization", "Bearer "+token)
	pushRec := httptest.NewRecorder()
	handler.ServeHTTP(pushRec, pushReq)
	if pushRec.Code != http.StatusOK {
		t.Fatalf("同步推送失败：%d %s", pushRec.Code, pushRec.Body.String())
	}

	pullReq := httptest.NewRequest(http.MethodGet, "/api/sync/pull?since=0", nil)
	pullReq.Header.Set("Authorization", "Bearer "+token)
	pullRec := httptest.NewRecorder()
	handler.ServeHTTP(pullRec, pullReq)
	if pullRec.Code != http.StatusOK {
		t.Fatalf("同步拉取失败：%d %s", pullRec.Code, pullRec.Body.String())
	}
	var body struct {
		Notes []struct {
			ID string `json:"id"`
		} `json:"notes"`
	}
	if err := json.Unmarshal(pullRec.Body.Bytes(), &body); err != nil {
		t.Fatalf("解析同步拉取响应失败：%v", err)
	}
	if len(body.Notes) != 1 || body.Notes[0].ID != "note_1" {
		t.Fatalf("同步拉取响应不符合预期：%s", pullRec.Body.String())
	}
}

// registerAndReturnAccessToken 注册测试账号并返回访问令牌。
func registerAndReturnAccessToken(t *testing.T, handler http.Handler) string {
	t.Helper()
	registerReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", strings.NewReader(`{"email":"sync@example.com","password":"pass123456","displayName":"用户"}`))
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
	return authResp.AccessToken
}
