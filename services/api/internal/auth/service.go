// 文件说明：认证和设备登记用例服务。
package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"time"
)

var (
	ErrInvalidInput       = errors.New("invalid input")
	ErrInvalidCredentials = errors.New("invalid credentials")
)

// Service 组合认证仓库和令牌管理器。
type Service struct {
	repo   Repository
	tokens *TokenManager
}

// RegisterInput 表示注册输入。
type RegisterInput struct {
	Email       string
	Password    string
	DisplayName string
}

// LoginInput 表示登录输入。
type LoginInput struct {
	Email    string
	Password string
}

// DeviceInput 表示设备登记输入。
type DeviceInput struct {
	DeviceName string
	Platform   string
}

// AuthResult 表示认证接口结果。
type AuthResult struct {
	User         PublicUser `json:"user"`
	AccessToken  string     `json:"accessToken"`
	RefreshToken string     `json:"refreshToken"`
}

// NewService 创建认证服务。
func NewService(repo Repository, tokens *TokenManager) *Service {
	return &Service{repo: repo, tokens: tokens}
}

// Register 注册新用户并返回令牌。
func (service *Service) Register(ctx context.Context, input RegisterInput) (AuthResult, error) {
	email := normalizeEmail(input.Email)
	if email == "" || len(input.Password) < 8 {
		return AuthResult{}, ErrInvalidInput
	}
	hash, err := HashPassword(input.Password)
	if err != nil {
		return AuthResult{}, err
	}
	user := User{
		ID:           newID("usr"),
		Email:        email,
		DisplayName:  strings.TrimSpace(input.DisplayName),
		PasswordHash: hash,
		CreatedAt:    time.Now(),
	}
	if err := service.repo.CreateUser(ctx, user); err != nil {
		return AuthResult{}, err
	}
	return service.issueAuthResult(ctx, user)
}

// Login 校验账号密码并返回令牌。
func (service *Service) Login(ctx context.Context, input LoginInput) (AuthResult, error) {
	user, err := service.repo.FindUserByEmail(ctx, input.Email)
	if err != nil {
		return AuthResult{}, ErrInvalidCredentials
	}
	if !ComparePassword(user.PasswordHash, input.Password) {
		return AuthResult{}, ErrInvalidCredentials
	}
	return service.issueAuthResult(ctx, user)
}

// Refresh 轮换刷新令牌并返回新令牌。
func (service *Service) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	hash := service.tokens.HashRefreshToken(refreshToken)
	session, err := service.repo.FindRefreshSession(ctx, hash)
	if err != nil || session.Revoked || time.Now().After(session.ExpiresAt) {
		return TokenPair{}, ErrInvalidCredentials
	}
	if err := service.repo.RevokeRefreshSession(ctx, hash); err != nil {
		return TokenPair{}, err
	}
	return service.issueTokenPair(ctx, session.UserID)
}

// Logout 撤销刷新令牌。
func (service *Service) Logout(ctx context.Context, refreshToken string) error {
	hash := service.tokens.HashRefreshToken(refreshToken)
	if err := service.repo.RevokeRefreshSession(ctx, hash); err != nil {
		return ErrInvalidCredentials
	}
	return nil
}

// RegisterDevice 登记当前用户设备。
func (service *Service) RegisterDevice(ctx context.Context, userID string, input DeviceInput) (PublicDevice, error) {
	if strings.TrimSpace(input.DeviceName) == "" || strings.TrimSpace(input.Platform) == "" {
		return PublicDevice{}, ErrInvalidInput
	}
	device := Device{
		ID:         newID("dev"),
		UserID:     userID,
		DeviceName: strings.TrimSpace(input.DeviceName),
		Platform:   strings.TrimSpace(input.Platform),
		CreatedAt:  time.Now(),
	}
	if err := service.repo.SaveDevice(ctx, device); err != nil {
		return PublicDevice{}, err
	}
	return ToPublicDevice(device), nil
}

// ParseAccessToken 解析访问令牌。
func (service *Service) ParseAccessToken(token string) (AccessClaims, error) {
	return service.tokens.ParseAccessToken(token)
}

// issueAuthResult 生成认证结果。
func (service *Service) issueAuthResult(ctx context.Context, user User) (AuthResult, error) {
	pair, err := service.issueTokenPair(ctx, user.ID)
	if err != nil {
		return AuthResult{}, err
	}
	return AuthResult{User: ToPublicUser(user), AccessToken: pair.AccessToken, RefreshToken: pair.RefreshToken}, nil
}

// issueTokenPair 生成访问令牌和刷新令牌。
func (service *Service) issueTokenPair(ctx context.Context, userID string) (TokenPair, error) {
	accessToken, err := service.tokens.IssueAccessToken(userID)
	if err != nil {
		return TokenPair{}, err
	}
	refreshToken, refreshHash, expiresAt, err := service.tokens.IssueRefreshToken()
	if err != nil {
		return TokenPair{}, err
	}
	if err := service.repo.SaveRefreshSession(ctx, RefreshSession{TokenHash: refreshHash, UserID: userID, ExpiresAt: expiresAt}); err != nil {
		return TokenPair{}, err
	}
	return TokenPair{AccessToken: accessToken, RefreshToken: refreshToken}, nil
}

// newID 生成带前缀的随机 ID。
func newID(prefix string) string {
	raw := make([]byte, 12)
	if _, err := rand.Read(raw); err == nil {
		return prefix + "_" + hex.EncodeToString(raw)
	}
	return prefix + "_" + strconv.FormatInt(time.Now().UnixNano(), 36)
}
