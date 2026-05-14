# API SQLite Auth Design

> 文件说明：记录 Go API 账号、刷新令牌和设备 SQLite 持久化设计。

## 背景

当前 Go API 的认证仓库是内存实现。服务进程重启后，账号、刷新令牌和设备登记都会丢失。客户端已经支持注册、登录、本地会话和设备登记；继续做笔记同步前，需要先让账号体系稳定持久化。

## 目标

- 新增 SQLite 认证仓库，实现现有 `auth.Repository` 接口。
- 持久化用户、刷新令牌会话和设备。
- API 默认使用本地 SQLite 文件。
- 保留内存仓库，继续用于单元测试和轻量场景。
- 注册、登录、刷新、退出和设备登记 HTTP 契约不变。

## 非目标

- 不引入 PostgreSQL 或迁移框架。
- 不实现笔记同步表。
- 不实现设备列表、设备删除或设备重命名。
- 不改变客户端 API 契约。

## 设计

新增 `internal/auth/sqlite_repository.go`。仓库初始化时创建三张表：

- `users`：`id`、`email`、`display_name`、`password_hash`、`created_at`。
- `refresh_sessions`：`token_hash`、`user_id`、`expires_at`、`revoked`。
- `devices`：`id`、`user_id`、`device_name`、`platform`、`created_at`。

SQLite 仓库复用现有错误：重复邮箱映射为 `ErrEmailExists`，重复用户 ID 映射为 `ErrUserIDExists`，未找到用户或会话时返回现有 not found 错误。刷新令牌消费和轮换使用事务，保持原子性。

服务启动时通过 `server.New()` 打开默认数据库路径。默认路径为当前工作目录下的 `data/auth.db`，后续可通过环境变量调整。测试使用临时数据库文件。

## 验收

- 注册账号后关闭并重新打开仓库，仍可通过邮箱找到用户。
- 登录生成的刷新令牌会话重开仓库后仍可刷新。
- 设备登记重开仓库后不破坏已有账号数据。
- `go test ./...` 通过。
