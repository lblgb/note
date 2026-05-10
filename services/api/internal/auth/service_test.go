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
