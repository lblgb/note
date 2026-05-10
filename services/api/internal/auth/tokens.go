// 文件说明：访问令牌和刷新令牌签发、校验逻辑。
package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

var ErrInvalidToken = errors.New("invalid token")

// AccessClaims 表示访问令牌载荷。
type AccessClaims struct {
	UserID    string `json:"userId"`
	ExpiresAt int64  `json:"expiresAt"`
}

// TokenManager 管理访问令牌和刷新令牌。
type TokenManager struct {
	secret     []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
}

// NewTokenManager 创建令牌管理器。
func NewTokenManager(secret []byte, accessTTL time.Duration, refreshTTL time.Duration) *TokenManager {
	return &TokenManager{secret: secret, accessTTL: accessTTL, refreshTTL: refreshTTL}
}

// IssueAccessToken 签发 HMAC 访问令牌。
func (manager *TokenManager) IssueAccessToken(userID string) (string, error) {
	claims := AccessClaims{UserID: userID, ExpiresAt: time.Now().Add(manager.accessTTL).Unix()}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	payloadText := base64.RawURLEncoding.EncodeToString(payload)
	signature := manager.sign(payloadText)
	return payloadText + "." + signature, nil
}

// ParseAccessToken 解析并验证访问令牌。
func (manager *TokenManager) ParseAccessToken(token string) (AccessClaims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return AccessClaims{}, ErrInvalidToken
	}
	if !hmac.Equal([]byte(manager.sign(parts[0])), []byte(parts[1])) {
		return AccessClaims{}, ErrInvalidToken
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return AccessClaims{}, ErrInvalidToken
	}
	var claims AccessClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return AccessClaims{}, ErrInvalidToken
	}
	if time.Now().Unix() >= claims.ExpiresAt {
		return AccessClaims{}, ErrInvalidToken
	}
	return claims, nil
}

// IssueRefreshToken 生成刷新令牌、哈希和过期时间。
func (manager *TokenManager) IssueRefreshToken() (string, string, time.Time, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", "", time.Time{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	return token, manager.HashRefreshToken(token), time.Now().Add(manager.refreshTTL), nil
}

// HashRefreshToken 生成刷新令牌服务端存储哈希。
func (manager *TokenManager) HashRefreshToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// sign 生成载荷签名。
func (manager *TokenManager) sign(payload string) string {
	mac := hmac.New(sha256.New, manager.secret)
	_, _ = mac.Write([]byte(payload))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
