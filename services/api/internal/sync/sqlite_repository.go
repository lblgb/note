// 文件说明：同步仓库 SQLite 实现，持久化文件夹、笔记和服务端变更版本。
package sync

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// SQLiteRepository 提供基于 SQLite 的同步数据仓库。
type SQLiteRepository struct {
	db *sql.DB
}

// OpenSQLiteRepository 打开或创建 SQLite 同步仓库。
func OpenSQLiteRepository(path string) (*SQLiteRepository, error) {
	cleanPath := filepath.Clean(path)
	if dir := filepath.Dir(cleanPath); dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return nil, err
		}
	}
	db, err := sql.Open("sqlite", cleanPath)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	repo := &SQLiteRepository{db: db}
	if err := repo.migrate(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return repo, nil
}

// Close 关闭 SQLite 数据库连接。
func (repo *SQLiteRepository) Close() error {
	return repo.db.Close()
}

// migrate 创建同步所需表结构。
func (repo *SQLiteRepository) migrate(ctx context.Context) error {
	statements := []string{
		`CREATE TABLE IF NOT EXISTS sync_versions (
			id INTEGER PRIMARY KEY CHECK (id = 1),
			version INTEGER NOT NULL
		)`,
		`INSERT OR IGNORE INTO sync_versions (id, version) VALUES (1, 0)`,
		`CREATE TABLE IF NOT EXISTS sync_folders (
			id TEXT NOT NULL,
			user_id TEXT NOT NULL,
			name TEXT NOT NULL,
			parent_id TEXT NOT NULL,
			deleted INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			server_version INTEGER NOT NULL,
			PRIMARY KEY (user_id, id)
		)`,
		`CREATE TABLE IF NOT EXISTS sync_notes (
			id TEXT NOT NULL,
			user_id TEXT NOT NULL,
			folder_id TEXT NOT NULL,
			title TEXT NOT NULL,
			body TEXT NOT NULL,
			deleted INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			server_version INTEGER NOT NULL,
			PRIMARY KEY (user_id, id)
		)`,
		`CREATE TABLE IF NOT EXISTS sync_changes (
			version INTEGER PRIMARY KEY,
			user_id TEXT NOT NULL,
			entity_type TEXT NOT NULL,
			entity_id TEXT NOT NULL,
			operation TEXT NOT NULL,
			changed_at INTEGER NOT NULL
		)`,
	}
	for _, statement := range statements {
		if _, err := repo.db.ExecContext(ctx, statement); err != nil {
			return err
		}
	}
	return nil
}

// Push 保存用户推送的文件夹和笔记并分配服务端版本。
func (repo *SQLiteRepository) Push(ctx context.Context, userID string, input PushInput) (PushResult, error) {
	tx, err := repo.db.BeginTx(ctx, nil)
	if err != nil {
		return PushResult{}, err
	}
	defer tx.Rollback()

	input = normalizeTimes(input)
	result := PushResult{}
	for _, folder := range input.Folders {
		version, err := repo.nextVersion(ctx, tx)
		if err != nil {
			return PushResult{}, err
		}
		folder.ServerVersion = version
		if _, err := tx.ExecContext(ctx, `INSERT OR REPLACE INTO sync_folders
			(id, user_id, name, parent_id, deleted, updated_at, server_version)
			VALUES (?, ?, ?, ?, ?, ?, ?)`,
			folder.ID, userID, folder.Name, folder.ParentID, boolToInt(folder.Deleted), folder.UpdatedAtNano, folder.ServerVersion,
		); err != nil {
			return PushResult{}, err
		}
		if err := repo.insertChange(ctx, tx, version, userID, "folder", folder.ID); err != nil {
			return PushResult{}, err
		}
		result.Folders = append(result.Folders, EntityVersion{ID: folder.ID, ServerVersion: version})
		result.ServerVersion = version
	}
	for _, note := range input.Notes {
		version, err := repo.nextVersion(ctx, tx)
		if err != nil {
			return PushResult{}, err
		}
		note.ServerVersion = version
		if _, err := tx.ExecContext(ctx, `INSERT OR REPLACE INTO sync_notes
			(id, user_id, folder_id, title, body, deleted, updated_at, server_version)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			note.ID, userID, note.FolderID, note.Title, note.Body, boolToInt(note.Deleted), note.UpdatedAtNano, note.ServerVersion,
		); err != nil {
			return PushResult{}, err
		}
		if err := repo.insertChange(ctx, tx, version, userID, "note", note.ID); err != nil {
			return PushResult{}, err
		}
		result.Notes = append(result.Notes, EntityVersion{ID: note.ID, ServerVersion: version})
		result.ServerVersion = version
	}
	if result.ServerVersion == 0 {
		version, err := repo.currentVersion(ctx, tx)
		if err != nil {
			return PushResult{}, err
		}
		result.ServerVersion = version
	}
	if err := tx.Commit(); err != nil {
		return PushResult{}, err
	}
	return result, nil
}

// Pull 拉取用户在指定版本之后的文件夹和笔记状态。
func (repo *SQLiteRepository) Pull(ctx context.Context, userID string, since int64) (PullResult, error) {
	result := PullResult{ServerVersion: since}
	version, err := repo.currentUserVersion(ctx, userID)
	if err != nil {
		return PullResult{}, err
	}
	if version > result.ServerVersion {
		result.ServerVersion = version
	}

	folders, err := repo.db.QueryContext(ctx, `SELECT id, name, parent_id, deleted, updated_at, server_version
		FROM sync_folders WHERE user_id = ? AND server_version > ? ORDER BY server_version`, userID, since)
	if err != nil {
		return PullResult{}, err
	}
	defer folders.Close()
	for folders.Next() {
		var folder Folder
		var deleted int
		if err := folders.Scan(&folder.ID, &folder.Name, &folder.ParentID, &deleted, &folder.UpdatedAtNano, &folder.ServerVersion); err != nil {
			return PullResult{}, err
		}
		folder.Deleted = deleted != 0
		folder.UpdatedAt = time.Unix(0, folder.UpdatedAtNano).UTC()
		result.Folders = append(result.Folders, folder)
	}
	if err := folders.Err(); err != nil {
		return PullResult{}, err
	}

	notes, err := repo.db.QueryContext(ctx, `SELECT id, folder_id, title, body, deleted, updated_at, server_version
		FROM sync_notes WHERE user_id = ? AND server_version > ? ORDER BY server_version`, userID, since)
	if err != nil {
		return PullResult{}, err
	}
	defer notes.Close()
	for notes.Next() {
		var note Note
		var deleted int
		if err := notes.Scan(&note.ID, &note.FolderID, &note.Title, &note.Body, &deleted, &note.UpdatedAtNano, &note.ServerVersion); err != nil {
			return PullResult{}, err
		}
		note.Deleted = deleted != 0
		note.UpdatedAt = time.Unix(0, note.UpdatedAtNano).UTC()
		result.Notes = append(result.Notes, note)
	}
	return result, notes.Err()
}

// nextVersion 在事务中分配下一个服务端版本。
func (repo *SQLiteRepository) nextVersion(ctx context.Context, tx *sql.Tx) (int64, error) {
	version, err := repo.currentVersion(ctx, tx)
	if err != nil {
		return 0, err
	}
	version++
	if _, err := tx.ExecContext(ctx, `UPDATE sync_versions SET version = ? WHERE id = 1`, version); err != nil {
		return 0, err
	}
	return version, nil
}

// currentVersion 在事务中读取当前服务端版本。
func (repo *SQLiteRepository) currentVersion(ctx context.Context, tx *sql.Tx) (int64, error) {
	var version int64
	if err := tx.QueryRowContext(ctx, `SELECT version FROM sync_versions WHERE id = 1`).Scan(&version); err != nil {
		return 0, err
	}
	return version, nil
}

// currentUserVersion 读取当前用户可见的最大服务端版本。
func (repo *SQLiteRepository) currentUserVersion(ctx context.Context, userID string) (int64, error) {
	var version int64
	if err := repo.db.QueryRowContext(ctx, `SELECT COALESCE(MAX(server_version), 0) FROM (
		SELECT server_version FROM sync_folders WHERE user_id = ?
		UNION ALL
		SELECT server_version FROM sync_notes WHERE user_id = ?
	)`, userID, userID).Scan(&version); err != nil {
		return 0, err
	}
	return version, nil
}

// insertChange 写入服务端变更日志。
func (repo *SQLiteRepository) insertChange(ctx context.Context, tx *sql.Tx, version int64, userID string, entityType string, entityID string) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO sync_changes
		(version, user_id, entity_type, entity_id, operation, changed_at)
		VALUES (?, ?, ?, ?, ?, ?)`,
		version, userID, entityType, entityID, "upsert", time.Now().UTC().UnixNano(),
	)
	return err
}

// boolToInt 将布尔值转换为 SQLite 整数。
func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}
