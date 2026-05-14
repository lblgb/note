// 文件说明：认证仓库 SQLite 实现，持久化用户、刷新会话和设备。
package auth

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// SQLiteRepository 提供基于 SQLite 的认证数据仓库。
type SQLiteRepository struct {
	db *sql.DB
}

// OpenSQLiteRepository 打开或创建 SQLite 认证仓库。
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

// migrate 创建认证所需表结构。
func (repo *SQLiteRepository) migrate(ctx context.Context) error {
	statements := []string{
		`PRAGMA foreign_keys = ON`,
		`CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			email TEXT NOT NULL UNIQUE,
			display_name TEXT NOT NULL,
			password_hash BLOB,
			created_at INTEGER NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS refresh_sessions (
			token_hash TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			expires_at INTEGER NOT NULL,
			revoked INTEGER NOT NULL DEFAULT 0,
			FOREIGN KEY(user_id) REFERENCES users(id)
		)`,
		`CREATE TABLE IF NOT EXISTS devices (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			device_name TEXT NOT NULL,
			platform TEXT NOT NULL,
			created_at INTEGER NOT NULL,
			FOREIGN KEY(user_id) REFERENCES users(id)
		)`,
	}
	for _, statement := range statements {
		if _, err := repo.db.ExecContext(ctx, statement); err != nil {
			return err
		}
	}
	return nil
}

// CreateUser 保存新用户并拒绝重复邮箱或 ID。
func (repo *SQLiteRepository) CreateUser(ctx context.Context, user User) error {
	_, err := repo.db.ExecContext(
		ctx,
		`INSERT INTO users (id, email, display_name, password_hash, created_at) VALUES (?, ?, ?, ?, ?)`,
		user.ID,
		normalizeEmail(user.Email),
		user.DisplayName,
		[]byte(user.PasswordHash),
		user.CreatedAt.UTC().UnixNano(),
	)
	if err == nil {
		return nil
	}
	if exists, lookupErr := repo.userIDExists(ctx, user.ID); lookupErr == nil && exists {
		return ErrUserIDExists
	}
	if exists, lookupErr := repo.emailExists(ctx, user.Email); lookupErr == nil && exists {
		return ErrEmailExists
	}
	return err
}

// FindUserByEmail 按邮箱查询用户。
func (repo *SQLiteRepository) FindUserByEmail(ctx context.Context, email string) (User, error) {
	return repo.scanUser(repo.db.QueryRowContext(
		ctx,
		`SELECT id, email, display_name, password_hash, created_at FROM users WHERE email = ?`,
		normalizeEmail(email),
	))
}

// FindUserByID 按 ID 查询用户。
func (repo *SQLiteRepository) FindUserByID(ctx context.Context, id string) (User, error) {
	return repo.scanUser(repo.db.QueryRowContext(
		ctx,
		`SELECT id, email, display_name, password_hash, created_at FROM users WHERE id = ?`,
		id,
	))
}

// SaveRefreshSession 保存刷新令牌会话。
func (repo *SQLiteRepository) SaveRefreshSession(ctx context.Context, session RefreshSession) error {
	_, err := repo.db.ExecContext(
		ctx,
		`INSERT OR REPLACE INTO refresh_sessions (token_hash, user_id, expires_at, revoked) VALUES (?, ?, ?, ?)`,
		session.TokenHash,
		session.UserID,
		session.ExpiresAt.UTC().UnixNano(),
		boolToInt(session.Revoked),
	)
	return err
}

// FindRefreshSession 按令牌哈希查询刷新会话。
func (repo *SQLiteRepository) FindRefreshSession(ctx context.Context, tokenHash string) (RefreshSession, error) {
	return repo.scanRefreshSession(repo.db.QueryRowContext(
		ctx,
		`SELECT token_hash, user_id, expires_at, revoked FROM refresh_sessions WHERE token_hash = ?`,
		tokenHash,
	))
}

// RevokeRefreshSession 撤销刷新令牌会话。
func (repo *SQLiteRepository) RevokeRefreshSession(ctx context.Context, tokenHash string) error {
	result, err := repo.db.ExecContext(ctx, `UPDATE refresh_sessions SET revoked = 1 WHERE token_hash = ?`, tokenHash)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrSessionNotFound
	}
	return nil
}

// ConsumeRefreshSession 原子消费未被撤销且未过期的刷新会话。
func (repo *SQLiteRepository) ConsumeRefreshSession(ctx context.Context, tokenHash string, now time.Time) (RefreshSession, error) {
	tx, err := repo.db.BeginTx(ctx, nil)
	if err != nil {
		return RefreshSession{}, err
	}
	defer tx.Rollback()

	session, err := repo.scanRefreshSession(tx.QueryRowContext(
		ctx,
		`SELECT token_hash, user_id, expires_at, revoked FROM refresh_sessions WHERE token_hash = ?`,
		tokenHash,
	))
	if err != nil {
		return RefreshSession{}, err
	}
	if session.Revoked || !now.Before(session.ExpiresAt) {
		return RefreshSession{}, ErrSessionNotFound
	}
	if _, err := tx.ExecContext(ctx, `UPDATE refresh_sessions SET revoked = 1 WHERE token_hash = ?`, tokenHash); err != nil {
		return RefreshSession{}, err
	}
	if err := tx.Commit(); err != nil {
		return RefreshSession{}, err
	}
	return session, nil
}

// RotateRefreshSession 原子撤销旧刷新会话并保存新会话。
func (repo *SQLiteRepository) RotateRefreshSession(ctx context.Context, oldTokenHash string, newSession RefreshSession, now time.Time) (RefreshSession, error) {
	tx, err := repo.db.BeginTx(ctx, nil)
	if err != nil {
		return RefreshSession{}, err
	}
	defer tx.Rollback()

	oldSession, err := repo.scanRefreshSession(tx.QueryRowContext(
		ctx,
		`SELECT token_hash, user_id, expires_at, revoked FROM refresh_sessions WHERE token_hash = ?`,
		oldTokenHash,
	))
	if err != nil {
		return RefreshSession{}, err
	}
	if oldSession.Revoked || !now.Before(oldSession.ExpiresAt) {
		return RefreshSession{}, ErrSessionNotFound
	}
	newSession.UserID = oldSession.UserID
	if _, err := tx.ExecContext(ctx, `UPDATE refresh_sessions SET revoked = 1 WHERE token_hash = ?`, oldTokenHash); err != nil {
		return RefreshSession{}, err
	}
	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO refresh_sessions (token_hash, user_id, expires_at, revoked) VALUES (?, ?, ?, ?)`,
		newSession.TokenHash,
		newSession.UserID,
		newSession.ExpiresAt.UTC().UnixNano(),
		boolToInt(newSession.Revoked),
	); err != nil {
		return RefreshSession{}, err
	}
	if err := tx.Commit(); err != nil {
		return RefreshSession{}, err
	}
	return oldSession, nil
}

// SaveDevice 保存用户设备。
func (repo *SQLiteRepository) SaveDevice(ctx context.Context, device Device) error {
	_, err := repo.db.ExecContext(
		ctx,
		`INSERT OR REPLACE INTO devices (id, user_id, device_name, platform, created_at) VALUES (?, ?, ?, ?, ?)`,
		device.ID,
		device.UserID,
		device.DeviceName,
		device.Platform,
		device.CreatedAt.UTC().UnixNano(),
	)
	return err
}

// scanUser 从单行结果读取用户。
func (repo *SQLiteRepository) scanUser(row *sql.Row) (User, error) {
	var user User
	var createdAt int64
	if err := row.Scan(&user.ID, &user.Email, &user.DisplayName, &user.PasswordHash, &createdAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return User{}, ErrUserNotFound
		}
		return User{}, err
	}
	user.CreatedAt = time.Unix(0, createdAt).UTC()
	return cloneUser(user), nil
}

// scanRefreshSession 从单行结果读取刷新会话。
func (repo *SQLiteRepository) scanRefreshSession(row *sql.Row) (RefreshSession, error) {
	var session RefreshSession
	var expiresAt int64
	var revoked int
	if err := row.Scan(&session.TokenHash, &session.UserID, &expiresAt, &revoked); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return RefreshSession{}, ErrSessionNotFound
		}
		return RefreshSession{}, err
	}
	session.ExpiresAt = time.Unix(0, expiresAt).UTC()
	session.Revoked = revoked != 0
	return session, nil
}

// userIDExists 判断用户 ID 是否已存在。
func (repo *SQLiteRepository) userIDExists(ctx context.Context, id string) (bool, error) {
	var exists int
	err := repo.db.QueryRowContext(ctx, `SELECT 1 FROM users WHERE id = ?`, id).Scan(&exists)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// emailExists 判断邮箱是否已存在。
func (repo *SQLiteRepository) emailExists(ctx context.Context, email string) (bool, error) {
	var exists int
	err := repo.db.QueryRowContext(ctx, `SELECT 1 FROM users WHERE email = ?`, normalizeEmail(email)).Scan(&exists)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// boolToInt 将布尔值转换为 SQLite 整数。
func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}
