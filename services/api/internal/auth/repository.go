// 文件说明：认证仓库接口和内存实现，后续可替换为 PostgreSQL 实现。
package auth

import (
	"context"
	"errors"
	"strings"
	"sync"
)

var (
	ErrEmailExists     = errors.New("email already exists")
	ErrUserNotFound    = errors.New("user not found")
	ErrSessionNotFound = errors.New("refresh session not found")
	ErrDeviceNotFound  = errors.New("device not found")
)

// Repository 定义认证和设备数据访问能力。
type Repository interface {
	CreateUser(ctx context.Context, user User) error
	FindUserByEmail(ctx context.Context, email string) (User, error)
	FindUserByID(ctx context.Context, id string) (User, error)
	SaveRefreshSession(ctx context.Context, session RefreshSession) error
	FindRefreshSession(ctx context.Context, tokenHash string) (RefreshSession, error)
	RevokeRefreshSession(ctx context.Context, tokenHash string) error
	SaveDevice(ctx context.Context, device Device) error
}

// MemoryRepository 提供线程安全的内存仓库。
type MemoryRepository struct {
	mu       sync.RWMutex
	users    map[string]User
	emailIDs map[string]string
	sessions map[string]RefreshSession
	devices  map[string]Device
}

// NewMemoryRepository 创建内存仓库。
func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		users:    map[string]User{},
		emailIDs: map[string]string{},
		sessions: map[string]RefreshSession{},
		devices:  map[string]Device{},
	}
}

// CreateUser 保存新用户并拒绝重复邮箱。
func (repo *MemoryRepository) CreateUser(ctx context.Context, user User) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	email := normalizeEmail(user.Email)
	if _, exists := repo.emailIDs[email]; exists {
		return ErrEmailExists
	}
	repo.users[user.ID] = user
	repo.emailIDs[email] = user.ID
	return nil
}

// FindUserByEmail 按邮箱查询用户。
func (repo *MemoryRepository) FindUserByEmail(ctx context.Context, email string) (User, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	id, exists := repo.emailIDs[normalizeEmail(email)]
	if !exists {
		return User{}, ErrUserNotFound
	}
	return repo.users[id], nil
}

// FindUserByID 按 ID 查询用户。
func (repo *MemoryRepository) FindUserByID(ctx context.Context, id string) (User, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	user, exists := repo.users[id]
	if !exists {
		return User{}, ErrUserNotFound
	}
	return user, nil
}

// SaveRefreshSession 保存刷新令牌会话。
func (repo *MemoryRepository) SaveRefreshSession(ctx context.Context, session RefreshSession) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	repo.sessions[session.TokenHash] = session
	return nil
}

// FindRefreshSession 按令牌哈希查询刷新会话。
func (repo *MemoryRepository) FindRefreshSession(ctx context.Context, tokenHash string) (RefreshSession, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	session, exists := repo.sessions[tokenHash]
	if !exists {
		return RefreshSession{}, ErrSessionNotFound
	}
	return session, nil
}

// RevokeRefreshSession 撤销刷新令牌会话。
func (repo *MemoryRepository) RevokeRefreshSession(ctx context.Context, tokenHash string) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	session, exists := repo.sessions[tokenHash]
	if !exists {
		return ErrSessionNotFound
	}
	session.Revoked = true
	repo.sessions[tokenHash] = session
	return nil
}

// SaveDevice 保存用户设备。
func (repo *MemoryRepository) SaveDevice(ctx context.Context, device Device) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	repo.devices[device.ID] = device
	return nil
}

// normalizeEmail 统一邮箱大小写和空白。
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}
