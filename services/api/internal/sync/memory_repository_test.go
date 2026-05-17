// 文件说明：测试内存同步仓库的版本分配和拉取行为。
package sync

import (
	"context"
	"testing"
	"time"
)

// TestMemoryRepositoryPushAndPull 验证推送文件夹和笔记后可按版本拉取。
func TestMemoryRepositoryPushAndPull(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	updatedAt := time.Date(2026, 5, 17, 9, 0, 0, 0, time.UTC)

	result, err := repo.Push(ctx, "usr_1", PushInput{
		Folders: []Folder{{
			ID:        "fld_inbox",
			Name:      "收件箱",
			UpdatedAt: updatedAt,
		}},
		Notes: []Note{{
			ID:        "note_1",
			FolderID:  "fld_inbox",
			Title:     "第一篇笔记",
			Body:      "正文",
			UpdatedAt: updatedAt.Add(time.Minute),
		}},
	})
	if err != nil {
		t.Fatalf("推送同步数据失败：%v", err)
	}
	if result.ServerVersion != 2 {
		t.Fatalf("期望服务端版本为 2，实际为 %d", result.ServerVersion)
	}
	if result.Folders[0].ServerVersion != 1 || result.Notes[0].ServerVersion != 2 {
		t.Fatalf("实体版本分配不符合预期：%+v", result)
	}

	pulled, err := repo.Pull(ctx, "usr_1", 0)
	if err != nil {
		t.Fatalf("拉取同步数据失败：%v", err)
	}
	if pulled.ServerVersion != 2 {
		t.Fatalf("期望拉取版本为 2，实际为 %d", pulled.ServerVersion)
	}
	if len(pulled.Folders) != 1 || pulled.Folders[0].Name != "收件箱" {
		t.Fatalf("拉取文件夹不符合预期：%+v", pulled.Folders)
	}
	if len(pulled.Notes) != 1 || pulled.Notes[0].Title != "第一篇笔记" {
		t.Fatalf("拉取笔记不符合预期：%+v", pulled.Notes)
	}

	empty, err := repo.Pull(ctx, "usr_1", pulled.ServerVersion)
	if err != nil {
		t.Fatalf("按最新版本拉取失败：%v", err)
	}
	if len(empty.Folders) != 0 || len(empty.Notes) != 0 || empty.ServerVersion != pulled.ServerVersion {
		t.Fatalf("最新版本后不应返回实体：%+v", empty)
	}
}

// TestMemoryRepositoryIsolatesUsers 验证不同用户只能拉取自己的同步数据。
func TestMemoryRepositoryIsolatesUsers(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()

	if _, err := repo.Push(ctx, "usr_1", PushInput{
		Notes: []Note{{ID: "note_1", Title: "用户 1 笔记", UpdatedAt: time.Now().UTC()}},
	}); err != nil {
		t.Fatalf("推送用户 1 笔记失败：%v", err)
	}

	pulled, err := repo.Pull(ctx, "usr_2", 0)
	if err != nil {
		t.Fatalf("拉取用户 2 数据失败：%v", err)
	}
	if len(pulled.Notes) != 0 || len(pulled.Folders) != 0 {
		t.Fatalf("用户 2 不应看到用户 1 数据：%+v", pulled)
	}
	if pulled.ServerVersion != 0 {
		t.Fatalf("用户 2 不应拿到用户 1 的版本号：%+v", pulled)
	}
}
