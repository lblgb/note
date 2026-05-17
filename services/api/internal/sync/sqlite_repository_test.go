// 文件说明：测试 SQLite 同步仓库的持久化和用户隔离。
package sync

import (
	"context"
	"path/filepath"
	"testing"
	"time"
)

// TestSQLiteRepositoryPersistsSyncData 验证同步数据跨仓库重开后仍可拉取。
func TestSQLiteRepositoryPersistsSyncData(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "sync.db")
	first, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("打开首个同步仓库失败：%v", err)
	}
	updatedAt := time.Date(2026, 5, 17, 10, 0, 0, 0, time.UTC)

	pushed, err := first.Push(ctx, "usr_1", PushInput{
		Folders: []Folder{{ID: "fld_inbox", Name: "收件箱", UpdatedAt: updatedAt}},
		Notes: []Note{{
			ID:        "note_1",
			FolderID:  "fld_inbox",
			Title:     "跨端笔记",
			Body:      "正文",
			UpdatedAt: updatedAt.Add(time.Minute),
		}},
	})
	if err != nil {
		t.Fatalf("推送同步数据失败：%v", err)
	}
	if err := first.Close(); err != nil {
		t.Fatalf("关闭首个同步仓库失败：%v", err)
	}

	second, err := OpenSQLiteRepository(path)
	if err != nil {
		t.Fatalf("重开同步仓库失败：%v", err)
	}
	defer second.Close()

	pulled, err := second.Pull(ctx, "usr_1", 0)
	if err != nil {
		t.Fatalf("重开后拉取同步数据失败：%v", err)
	}
	if pulled.ServerVersion != pushed.ServerVersion {
		t.Fatalf("期望服务端版本 %d，实际为 %d", pushed.ServerVersion, pulled.ServerVersion)
	}
	if len(pulled.Folders) != 1 || pulled.Folders[0].ID != "fld_inbox" {
		t.Fatalf("重开后文件夹不符合预期：%+v", pulled.Folders)
	}
	if len(pulled.Notes) != 1 || pulled.Notes[0].Title != "跨端笔记" {
		t.Fatalf("重开后笔记不符合预期：%+v", pulled.Notes)
	}
}

// TestSQLiteRepositoryIsolatesUsers 验证 SQLite 同步仓库按用户隔离数据。
func TestSQLiteRepositoryIsolatesUsers(t *testing.T) {
	ctx := context.Background()
	repo, err := OpenSQLiteRepository(filepath.Join(t.TempDir(), "sync.db"))
	if err != nil {
		t.Fatalf("打开同步仓库失败：%v", err)
	}
	defer repo.Close()

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
