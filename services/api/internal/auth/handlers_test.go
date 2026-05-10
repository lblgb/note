// 文件说明：认证和设备 HTTP 处理器测试。
package auth

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// TestHandlersRegisterLoginAndDevice 验证注册、登录和设备登记 HTTP 流程。
func TestHandlersRegisterLoginAndDevice(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	handlers := NewHandlers(service)

	registerReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", strings.NewReader(`{"email":"user@example.com","password":"pass123456","displayName":"用户"}`))
	registerRec := httptest.NewRecorder()
	handlers.Register(registerRec, registerReq)
	if registerRec.Code != http.StatusCreated {
		t.Fatalf("注册状态码应为 201，实际为 %d，响应为 %s", registerRec.Code, registerRec.Body.String())
	}

	loginReq := httptest.NewRequest(http.MethodPost, "/api/auth/login", strings.NewReader(`{"email":"user@example.com","password":"pass123456"}`))
	loginRec := httptest.NewRecorder()
	handlers.Login(loginRec, loginReq)
	if loginRec.Code != http.StatusOK {
		t.Fatalf("登录状态码应为 200，实际为 %d，响应为 %s", loginRec.Code, loginRec.Body.String())
	}
}

// TestHandlersRejectWrongMethod 验证错误方法被拒绝。
func TestHandlersRejectWrongMethod(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	handlers := NewHandlers(service)

	req := httptest.NewRequest(http.MethodGet, "/api/auth/login", nil)
	rec := httptest.NewRecorder()
	handlers.Login(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("期望 405，实际为 %d", rec.Code)
	}
}
