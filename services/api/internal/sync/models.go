// 文件说明：定义文件夹和笔记同步领域模型。
package sync

import "time"

// Folder 表示服务端保存的文件夹状态。
type Folder struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	ParentID      string    `json:"parentId,omitempty"`
	Deleted       bool      `json:"deleted"`
	UpdatedAt     time.Time `json:"-"`
	UpdatedAtNano int64     `json:"updatedAt"`
	ServerVersion int64     `json:"serverVersion"`
}

// Note 表示服务端保存的笔记状态。
type Note struct {
	ID            string    `json:"id"`
	FolderID      string    `json:"folderId,omitempty"`
	Title         string    `json:"title"`
	Body          string    `json:"body"`
	Deleted       bool      `json:"deleted"`
	UpdatedAt     time.Time `json:"-"`
	UpdatedAtNano int64     `json:"updatedAt"`
	ServerVersion int64     `json:"serverVersion"`
}

// EntityVersion 表示推送后实体获得的服务端版本。
type EntityVersion struct {
	ID            string `json:"id"`
	ServerVersion int64  `json:"serverVersion"`
}

// PushInput 表示客户端推送的同步数据。
type PushInput struct {
	Folders []Folder `json:"folders"`
	Notes   []Note   `json:"notes"`
}

// PushResult 表示推送后的版本分配结果。
type PushResult struct {
	ServerVersion int64           `json:"serverVersion"`
	Folders       []EntityVersion `json:"folders"`
	Notes         []EntityVersion `json:"notes"`
}

// PullResult 表示客户端拉取到的远端变更。
type PullResult struct {
	ServerVersion int64    `json:"serverVersion"`
	Folders       []Folder `json:"folders"`
	Notes         []Note   `json:"notes"`
}

// normalizeTimes 统一填充 JSON 使用的纳秒时间。
func normalizeTimes(input PushInput) PushInput {
	for index := range input.Folders {
		input.Folders[index].UpdatedAtNano = normalizeUnixNano(input.Folders[index].UpdatedAt, input.Folders[index].UpdatedAtNano)
	}
	for index := range input.Notes {
		input.Notes[index].UpdatedAtNano = normalizeUnixNano(input.Notes[index].UpdatedAt, input.Notes[index].UpdatedAtNano)
	}
	return input
}

// normalizeUnixNano 优先使用明确时间，其次保留 JSON 中的 Unix 纳秒。
func normalizeUnixNano(value time.Time, fallback int64) int64 {
	if value.IsZero() {
		return fallback
	}
	return value.UTC().UnixNano()
}
