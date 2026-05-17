// 文件说明：定义同步仓库接口和内存实现。
package sync

import (
	"context"
	"sync"
)

// Repository 定义文件夹和笔记同步数据访问能力。
type Repository interface {
	Push(ctx context.Context, userID string, input PushInput) (PushResult, error)
	Pull(ctx context.Context, userID string, since int64) (PullResult, error)
}

// MemoryRepository 提供测试用内存同步仓库。
type MemoryRepository struct {
	mu      sync.RWMutex
	version int64
	folders map[string]map[string]Folder
	notes   map[string]map[string]Note
}

// NewMemoryRepository 创建内存同步仓库。
func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		folders: map[string]map[string]Folder{},
		notes:   map[string]map[string]Note{},
	}
}

// Push 保存用户推送的文件夹和笔记并分配服务端版本。
func (repo *MemoryRepository) Push(ctx context.Context, userID string, input PushInput) (PushResult, error) {
	repo.mu.Lock()
	defer repo.mu.Unlock()

	input = normalizeTimes(input)
	if _, exists := repo.folders[userID]; !exists {
		repo.folders[userID] = map[string]Folder{}
	}
	if _, exists := repo.notes[userID]; !exists {
		repo.notes[userID] = map[string]Note{}
	}

	result := PushResult{}
	for _, folder := range input.Folders {
		repo.version++
		folder.ServerVersion = repo.version
		repo.folders[userID][folder.ID] = folder
		result.Folders = append(result.Folders, EntityVersion{ID: folder.ID, ServerVersion: folder.ServerVersion})
		result.ServerVersion = repo.version
	}
	for _, note := range input.Notes {
		repo.version++
		note.ServerVersion = repo.version
		repo.notes[userID][note.ID] = note
		result.Notes = append(result.Notes, EntityVersion{ID: note.ID, ServerVersion: note.ServerVersion})
		result.ServerVersion = repo.version
	}
	if result.ServerVersion == 0 {
		result.ServerVersion = repo.version
	}
	return result, nil
}

// Pull 拉取用户在指定版本之后的文件夹和笔记状态。
func (repo *MemoryRepository) Pull(ctx context.Context, userID string, since int64) (PullResult, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()

	result := PullResult{ServerVersion: since}
	for _, folder := range repo.folders[userID] {
		if folder.ServerVersion > result.ServerVersion {
			result.ServerVersion = folder.ServerVersion
		}
		if folder.ServerVersion > since {
			result.Folders = append(result.Folders, folder)
		}
	}
	for _, note := range repo.notes[userID] {
		if note.ServerVersion > result.ServerVersion {
			result.ServerVersion = note.ServerVersion
		}
		if note.ServerVersion > since {
			result.Notes = append(result.Notes, note)
		}
	}
	return result, nil
}
