// 文件说明：访问令牌和刷新令牌测试。
package auth

import (
	"testing"
	"time"
)

// TestAccessTokenRoundTrip 验证访问令牌签发和解析。
func TestAccessTokenRoundTrip(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)

	token, err := manager.IssueAccessToken("usr_test")
	if err != nil {
		t.Fatalf("签发访问令牌失败：%v", err)
	}
	claims, err := manager.ParseAccessToken(token)
	if err != nil {
		t.Fatalf("解析访问令牌失败：%v", err)
	}
	if claims.UserID != "usr_test" {
		t.Fatalf("期望用户 ID usr_test，实际为 %q", claims.UserID)
	}
}

// TestRefreshTokenAndHash 验证刷新令牌生成和哈希稳定性。
func TestRefreshTokenAndHash(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)

	token, hash, expiresAt, err := manager.IssueRefreshToken()
	if err != nil {
		t.Fatalf("签发刷新令牌失败：%v", err)
	}
	if token == "" || hash == "" {
		t.Fatal("刷新令牌和哈希不能为空")
	}
	if hash != manager.HashRefreshToken(token) {
		t.Fatal("刷新令牌哈希应稳定")
	}
	if !expiresAt.After(time.Now()) {
		t.Fatal("刷新令牌过期时间应在未来")
	}
}
