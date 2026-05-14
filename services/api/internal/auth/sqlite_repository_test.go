// 文件说明：测试 SQLite 认证仓库的持久化和刷新令牌事务行为。
package auth

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

// openTestSQLiteRepository 打开每个测试独立使用的 SQLite 仓库。
func openTestSQLiteRepository(t *testing.T) *SQLiteRepository {
	t.Helper()
	repo, err := OpenSQLiteRepository(filepath.Join(t.TempDir(), "auth.db"))
	if err != nil {
		t.Fatalf("打开 SQLite 仓库失败：%v", err)
	}
	t.Cleanup(func() {
		if err := repo.Close(); err != nil {
			t.Fatalf("关闭 SQLite 仓库失败：%v", err)
		}
	})
	return repo
}

// TestSQLiteRepositoryPersistsUsers 验证用户在仓库重开后仍可读取。
func TestSQLiteRepositoryPersistsUsers(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "auth.db")
	first, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("打开首个仓库失败：%v", err)
	}
	user := User{
		ID:           "usr_test",
		Email:        "USER@example.com",
		DisplayName:  "用户",
		PasswordHash: []byte("hash"),
		CreatedAt:    time.Date(2026, 5, 14, 1, 0, 0, 0, time.UTC),
	}
	if err := first.CreateUser(ctx, user); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	if err := first.Close(); err != nil {
		t.Fatalf("关闭首个仓库失败：%v", err)
	}

	second, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("重开仓库失败：%v", err)
	}
	defer second.Close()

	got, err := second.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("重开后查询用户失败：%v", err)
	}
	if got.ID != user.ID || got.DisplayName != user.DisplayName || string(got.PasswordHash) != "hash" {
		t.Fatalf("重开后用户不匹配：%+v", got)
	}
}

// TestSQLiteRepositoryRejectsDuplicateEmail 验证 SQLite 仓库拒绝重复邮箱。
func TestSQLiteRepositoryRejectsDuplicateEmail(t *testing.T) {
	repo := openTestSQLiteRepository(t)
	ctx := context.Background()

	if err := repo.CreateUser(ctx, User{ID: "usr_first", Email: "user@example.com"}); err != nil {
		t.Fatalf("创建首个用户失败：%v", err)
	}
	if err := repo.CreateUser(ctx, User{ID: "usr_second", Email: "USER@example.com"}); !errors.Is(err, ErrEmailExists) {
		t.Fatalf("期望 ErrEmailExists，实际为 %v", err)
	}
}

// TestSQLiteRepositoryCreatesParentDirectory 验证仓库会自动创建数据库父目录。
func TestSQLiteRepositoryCreatesParentDirectory(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "auth.db")
	repo, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("打开嵌套路径 SQLite 仓库失败：%v", err)
	}
	defer repo.Close()

	if _, err := repo.FindUserByEmail(context.Background(), "missing@example.com"); !errors.Is(err, ErrUserNotFound) {
		t.Fatalf("期望仓库已完成迁移并返回 ErrUserNotFound，实际为 %v", err)
	}
}

// TestSQLiteRepositoryPersistsRefreshSessions 验证刷新会话可跨仓库重开使用。
func TestSQLiteRepositoryPersistsRefreshSessions(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "auth.db")
	first, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("打开首个仓库失败：%v", err)
	}
	session := RefreshSession{
		TokenHash: "refresh_hash",
		UserID:    "usr_test",
		ExpiresAt: time.Now().Add(time.Hour).UTC(),
	}
	if err := first.CreateUser(ctx, User{ID: session.UserID, Email: "user@example.com"}); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	if err := first.SaveRefreshSession(ctx, session); err != nil {
		t.Fatalf("保存刷新会话失败：%v", err)
	}
	if err := first.Close(); err != nil {
		t.Fatalf("关闭首个仓库失败：%v", err)
	}

	second, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("重开仓库失败：%v", err)
	}
	defer second.Close()

	got, err := second.FindRefreshSession(ctx, session.TokenHash)
	if err != nil {
		t.Fatalf("重开后查询刷新会话失败：%v", err)
	}
	if got.UserID != session.UserID || got.Revoked {
		t.Fatalf("重开后刷新会话不匹配：%+v", got)
	}
}

// TestSQLiteRepositoryRotateRefreshSessionRevokesOldAndSavesNew 验证刷新轮换原子更新旧会话和新会话。
func TestSQLiteRepositoryRotateRefreshSessionRevokesOldAndSavesNew(t *testing.T) {
	repo := openTestSQLiteRepository(t)
	ctx := context.Background()
	now := time.Now().UTC()
	oldSession := RefreshSession{TokenHash: "old_hash", UserID: "usr_test", ExpiresAt: now.Add(time.Hour)}
	newSession := RefreshSession{TokenHash: "new_hash", ExpiresAt: now.Add(2 * time.Hour)}

	if err := repo.CreateUser(ctx, User{ID: oldSession.UserID, Email: "user@example.com"}); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	if err := repo.SaveRefreshSession(ctx, oldSession); err != nil {
		t.Fatalf("保存旧会话失败：%v", err)
	}
	rotated, err := repo.RotateRefreshSession(ctx, oldSession.TokenHash, newSession, now)
	if err != nil {
		t.Fatalf("轮换刷新会话失败：%v", err)
	}
	if rotated.TokenHash != oldSession.TokenHash {
		t.Fatalf("期望返回旧会话，实际为 %+v", rotated)
	}
	oldGot, err := repo.FindRefreshSession(ctx, oldSession.TokenHash)
	if err != nil {
		t.Fatalf("查询旧会话失败：%v", err)
	}
	if !oldGot.Revoked {
		t.Fatal("旧会话应被撤销")
	}
	newGot, err := repo.FindRefreshSession(ctx, newSession.TokenHash)
	if err != nil {
		t.Fatalf("查询新会话失败：%v", err)
	}
	if newGot.UserID != oldSession.UserID {
		t.Fatalf("新会话应继承用户 ID，实际为 %q", newGot.UserID)
	}
}

// TestSQLiteRepositorySaveDevice 验证设备登记写入 SQLite 仓库。
func TestSQLiteRepositorySaveDevice(t *testing.T) {
	repo := openTestSQLiteRepository(t)
	ctx := context.Background()

	device := Device{
		ID:         "dev_test",
		UserID:     "usr_test",
		DeviceName: "Windows 设备",
		Platform:   "windows",
		CreatedAt:  time.Now().UTC(),
	}
	if err := repo.CreateUser(ctx, User{ID: device.UserID, Email: "user@example.com"}); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	if err := repo.SaveDevice(ctx, device); err != nil {
		t.Fatalf("保存设备失败：%v", err)
	}
}
