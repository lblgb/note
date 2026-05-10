// 文件说明：访问令牌和刷新令牌测试。
package auth

import (
	"errors"
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

// TestNewTokenManagerPanicsOnEmptySecret 验证空密钥会快速失败。
func TestNewTokenManagerPanicsOnEmptySecret(t *testing.T) {
	assertPanics(t, func() {
		NewTokenManager(nil, time.Hour, 24*time.Hour)
	})
	assertPanics(t, func() {
		NewTokenManager([]byte{}, time.Hour, 24*time.Hour)
	})
}

// TestNewTokenManagerPanicsOnNonpositiveAccessTTL 验证访问令牌 TTL 必须为正数。
func TestNewTokenManagerPanicsOnNonpositiveAccessTTL(t *testing.T) {
	assertPanics(t, func() {
		NewTokenManager([]byte("test-secret"), 0, 24*time.Hour)
	})
	assertPanics(t, func() {
		NewTokenManager([]byte("test-secret"), -time.Second, 24*time.Hour)
	})
}

// TestNewTokenManagerPanicsOnNonpositiveRefreshTTL 验证刷新令牌 TTL 必须为正数。
func TestNewTokenManagerPanicsOnNonpositiveRefreshTTL(t *testing.T) {
	assertPanics(t, func() {
		NewTokenManager([]byte("test-secret"), time.Hour, 0)
	})
	assertPanics(t, func() {
		NewTokenManager([]byte("test-secret"), time.Hour, -time.Second)
	})
}

// TestTokenManagerCopiesSecret 验证构造后修改原始密钥不会影响令牌校验。
func TestTokenManagerCopiesSecret(t *testing.T) {
	secret := []byte("test-secret")
	manager := NewTokenManager(secret, time.Hour, 24*time.Hour)

	token, err := manager.IssueAccessToken("usr_test")
	if err != nil {
		t.Fatalf("签发访问令牌失败：%v", err)
	}
	for i := range secret {
		secret[i] = 'x'
	}
	claims, err := manager.ParseAccessToken(token)
	if err != nil {
		t.Fatalf("解析访问令牌失败：%v", err)
	}
	if claims.UserID != "usr_test" {
		t.Fatalf("期望用户 ID usr_test，实际为 %q", claims.UserID)
	}
}

// TestTamperedAccessTokenRejected 验证篡改后的访问令牌会被拒绝。
func TestTamperedAccessTokenRejected(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)

	token, err := manager.IssueAccessToken("usr_test")
	if err != nil {
		t.Fatalf("签发访问令牌失败：%v", err)
	}
	if _, err := manager.ParseAccessToken(tamperToken(token)); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("期望 ErrInvalidToken，实际为 %v", err)
	}
}

// TestAccessTokenSignedWithDifferentSecretRejected 验证不同密钥签发的访问令牌会被拒绝。
func TestAccessTokenSignedWithDifferentSecretRejected(t *testing.T) {
	issuer := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)
	parser := NewTokenManager([]byte("other-secret"), time.Hour, 24*time.Hour)

	token, err := issuer.IssueAccessToken("usr_test")
	if err != nil {
		t.Fatalf("签发访问令牌失败：%v", err)
	}
	if _, err := parser.ParseAccessToken(token); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("期望 ErrInvalidToken，实际为 %v", err)
	}
}

// TestExpiredAccessTokenRejected 验证过期访问令牌会被拒绝。
func TestExpiredAccessTokenRejected(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Nanosecond, 24*time.Hour)

	token, err := manager.IssueAccessToken("usr_test")
	if err != nil {
		t.Fatalf("签发访问令牌失败：%v", err)
	}
	time.Sleep(2 * time.Millisecond)
	if _, err := manager.ParseAccessToken(token); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("期望 ErrInvalidToken，实际为 %v", err)
	}
}

// TestRefreshTokensAreUniqueAndNontrivial 验证刷新令牌唯一且长度足够。
func TestRefreshTokensAreUniqueAndNontrivial(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)

	first, _, _, err := manager.IssueRefreshToken()
	if err != nil {
		t.Fatalf("签发第一个刷新令牌失败：%v", err)
	}
	second, _, _, err := manager.IssueRefreshToken()
	if err != nil {
		t.Fatalf("签发第二个刷新令牌失败：%v", err)
	}
	if first == second {
		t.Fatal("刷新令牌应唯一")
	}
	if len(first) < 32 || len(second) < 32 {
		t.Fatalf("刷新令牌长度不足：first=%d second=%d", len(first), len(second))
	}
}

func assertPanics(t *testing.T, run func()) {
	t.Helper()
	defer func() {
		if recover() == nil {
			t.Fatal("期望发生 panic")
		}
	}()
	run()
}

func tamperToken(token string) string {
	last := token[len(token)-1]
	if last == 'A' {
		return token[:len(token)-1] + "B"
	}
	return token[:len(token)-1] + "A"
}
