// 文件说明：认证服务和内存仓库测试。
package auth

import (
	"context"
	"testing"
)

// TestMemoryRepositoryCreateAndFindUser 验证用户创建和邮箱查询。
func TestMemoryRepositoryCreateAndFindUser(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", DisplayName: "用户", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}

	got, err := repo.FindUserByEmail(ctx, "USER@example.com")
	if err != nil {
		t.Fatalf("查询用户失败：%v", err)
	}
	if got.ID != user.ID {
		t.Fatalf("期望用户 ID %q，实际为 %q", user.ID, got.ID)
	}
}

// TestMemoryRepositoryRejectsDuplicateEmail 验证重复邮箱会被拒绝。
func TestMemoryRepositoryRejectsDuplicateEmail(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("首次创建用户失败：%v", err)
	}
	if err := repo.CreateUser(ctx, User{ID: "usr_other", Email: "USER@example.com"}); err != ErrEmailExists {
		t.Fatalf("期望 ErrEmailExists，实际为 %v", err)
	}
}

// TestMemoryRepositoryClonesPasswordHashOnCreate 验证写入后外部哈希修改不会影响仓库状态。
func TestMemoryRepositoryClonesPasswordHashOnCreate(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	hash := []byte("hash")

	if err := repo.CreateUser(ctx, User{ID: "usr_test", Email: "user@example.com", PasswordHash: hash}); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	hash[0] = 'X'

	got, err := repo.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("查询用户失败：%v", err)
	}
	if string(got.PasswordHash) != "hash" {
		t.Fatalf("期望仓库哈希保持为 %q，实际为 %q", "hash", string(got.PasswordHash))
	}
}

// TestMemoryRepositoryClonesPasswordHashOnRead 验证读取结果的哈希修改不会影响仓库状态。
func TestMemoryRepositoryClonesPasswordHashOnRead(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	byEmail, err := repo.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("按邮箱查询用户失败：%v", err)
	}
	byEmail.PasswordHash[0] = 'X'

	byID, err := repo.FindUserByID(ctx, user.ID)
	if err != nil {
		t.Fatalf("按 ID 查询用户失败：%v", err)
	}
	if string(byID.PasswordHash) != "hash" {
		t.Fatalf("期望按邮箱读取结果不影响仓库哈希，实际为 %q", string(byID.PasswordHash))
	}
	byID.PasswordHash[0] = 'Y'

	got, err := repo.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("再次按邮箱查询用户失败：%v", err)
	}
	if string(got.PasswordHash) != "hash" {
		t.Fatalf("期望按 ID 读取结果不影响仓库哈希，实际为 %q", string(got.PasswordHash))
	}
}

// TestMemoryRepositoryRejectsDuplicateID 验证重复用户 ID 会被拒绝且邮箱索引不被破坏。
func TestMemoryRepositoryRejectsDuplicateID(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	first := User{ID: "usr_test", Email: "first@example.com", PasswordHash: []byte("hash")}
	second := User{ID: "usr_test", Email: "second@example.com", PasswordHash: []byte("other")}

	if err := repo.CreateUser(ctx, first); err != nil {
		t.Fatalf("首次创建用户失败：%v", err)
	}
	if err := repo.CreateUser(ctx, second); err != ErrUserIDExists {
		t.Fatalf("期望 ErrUserIDExists，实际为 %v", err)
	}

	got, err := repo.FindUserByEmail(ctx, "first@example.com")
	if err != nil {
		t.Fatalf("查询首个邮箱失败：%v", err)
	}
	if got.ID != first.ID || got.Email != first.Email {
		t.Fatalf("期望首个邮箱仍解析为首个用户，实际为 ID=%q Email=%q", got.ID, got.Email)
	}
	if _, err := repo.FindUserByEmail(ctx, "second@example.com"); err != ErrUserNotFound {
		t.Fatalf("期望第二个邮箱未写入索引，实际为 %v", err)
	}
}
