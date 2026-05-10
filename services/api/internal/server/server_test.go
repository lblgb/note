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
