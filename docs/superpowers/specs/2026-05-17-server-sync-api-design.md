# 服务端最小同步 API 设计

> 文件说明：本文档记录服务端文件夹和笔记最小同步 API 的设计范围。

## 目标

本阶段为多端同步建立服务端数据面。客户端后续可以把本地文件夹和笔记变更上传到服务端，并从服务端拉取指定版本之后的变更。

## 范围

本阶段包含：

- 服务端持久化文件夹、笔记和服务端变更日志。
- 提供 `POST /api/sync/push` 上传本地变更。
- 提供 `GET /api/sync/pull?since=版本号` 拉取远端变更。
- 所有同步接口必须使用 `Authorization: Bearer <accessToken>`。
- 数据按用户隔离，用户只能读写自己的文件夹和笔记。

本阶段不包含：

- 客户端同步队列接入。
- 图片附件上传下载。
- 自动冲突合并。
- PostgreSQL 切换。

## 数据模型

服务端 SQLite 增加三类表：

- `sync_folders`：保存用户文件夹最新状态。
- `sync_notes`：保存用户笔记最新状态。
- `sync_changes`：保存服务端递增变更日志。

文件夹字段：

- `id`：客户端生成的稳定 ID。
- `user_id`：所属用户。
- `name`：文件夹名称。
- `parent_id`：父文件夹 ID，可为空。
- `deleted`：软删除标记。
- `updated_at`：客户端更新时间，Unix 纳秒。
- `server_version`：服务端写入版本。

笔记字段：

- `id`：客户端生成的稳定 ID。
- `user_id`：所属用户。
- `folder_id`：所属文件夹 ID，可为空。
- `title`：标题。
- `body`：Markdown 正文。
- `deleted`：软删除标记。
- `updated_at`：客户端更新时间，Unix 纳秒。
- `server_version`：服务端写入版本。

变更日志字段：

- `version`：服务端全局递增版本。
- `user_id`：所属用户。
- `entity_type`：`folder` 或 `note`。
- `entity_id`：实体 ID。
- `operation`：本阶段统一使用 `upsert`，软删除由实体 `deleted` 字段表达。
- `changed_at`：服务端记录时间，Unix 纳秒。

## API 设计

### 推送变更

```text
POST /api/sync/push
```

请求：

```json
{
  "folders": [
    {
      "id": "fld_inbox",
      "name": "收件箱",
      "parentId": null,
      "deleted": false,
      "updatedAt": 1770000000000000000
    }
  ],
  "notes": [
    {
      "id": "note_1",
      "folderId": "fld_inbox",
      "title": "第一篇笔记",
      "body": "正文",
      "deleted": false,
      "updatedAt": 1770000000000000000
    }
  ]
}
```

响应：

```json
{
  "serverVersion": 12,
  "folders": [{"id":"fld_inbox","serverVersion":11}],
  "notes": [{"id":"note_1","serverVersion":12}]
}
```

规则：

- `folders` 和 `notes` 可以为空，但请求不能完全没有 JSON 对象。
- 每个实体写入时分配一个新的服务端版本。
- 同一请求内先写文件夹，再写笔记。
- 本阶段如果服务端已有同 ID 实体，直接覆盖为最新状态，不做冲突判断。

### 拉取变更

```text
GET /api/sync/pull?since=0
```

响应：

```json
{
  "serverVersion": 12,
  "folders": [
    {
      "id": "fld_inbox",
      "name": "收件箱",
      "parentId": null,
      "deleted": false,
      "updatedAt": 1770000000000000000,
      "serverVersion": 11
    }
  ],
  "notes": [
    {
      "id": "note_1",
      "folderId": "fld_inbox",
      "title": "第一篇笔记",
      "body": "正文",
      "deleted": false,
      "updatedAt": 1770000000000000000,
      "serverVersion": 12
    }
  ]
}
```

规则：

- `since` 缺省为 `0`。
- 只返回当前用户在 `since` 之后发生变化的实体。
- `serverVersion` 返回当前用户可见的最大服务端版本；没有变更时为 `since` 和数据库最大版本中的较大值。

## 错误处理

- 未登录或令牌无效返回 `401 unauthorized`。
- JSON 无效、字段缺失或 `since` 非数字返回 `400 invalid_request`。
- 服务端存储失败返回 `500 internal_error`。
- 错误结构沿用现有 `{"error":{"code":"...","message":"..."}}`。

## 测试策略

- 仓库测试验证 push 后可 pull，并验证数据跨仓库重开仍存在。
- 仓库测试验证不同用户的数据隔离。
- HTTP 测试验证未登录不能访问同步接口。
- HTTP 测试验证登录后 push 再 pull 能返回文件夹和笔记。
- 全量运行 `go test -count=1 ./...`。
