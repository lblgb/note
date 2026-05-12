# SQLite 本地笔记持久化设计

> 文件说明：本文档定义 SQLite 本地笔记持久化第一版的目标、边界、数据结构和验证方式。

## 目标

第一版 SQLite 持久化只负责文件夹和笔记的本地保存，让用户在 Windows 或 Android 客户端中新建、编辑笔记后，重启应用仍能看到改动后的数据。

## 范围

- 持久化文件夹列表。
- 持久化笔记列表、标题、正文、所属文件夹和更新时间。
- 首次启动时写入当前内存版种子文件夹和种子笔记。
- 后续启动读取 SQLite 中的数据，不重复插入种子数据。
- 继续复用现有 `NoteRepository` 接口和 `NoteBrowserPage` 页面。

## 暂不包含

- 图片附件表和对象存储。
- 标签、笔记标签关联表。
- 内部笔记链接索引。
- 同步队列、冲突处理和账号隔离。
- 富文本或 Markdown 渲染。

## 技术方案

客户端使用 `sqlite3` 作为第一版 SQLite 依赖。现有 `NoteRepository` 是同步接口，`sqlite3` 可以保持页面侧同步读写模型不扩散，先满足 Windows 开发和自动化测试的持久化闭环。Windows 配置为使用系统自带的 `winsqlite3.dll`，避免测试或运行时从 GitHub 下载预编译库。移动端正式打包时再补充平台原生 SQLite 库依赖。

新增 `SqliteNoteRepository`，实现现有 `NoteRepository` 接口。页面默认仓储从 `InMemoryNoteRepository` 切换到异步创建的 SQLite 仓储，测试仍可注入内存仓储。

## 数据模型

`folders` 表：

- `id TEXT PRIMARY KEY`
- `name TEXT NOT NULL`
- `created_at TEXT NOT NULL`

`notes` 表：

- `id TEXT PRIMARY KEY`
- `folder_id TEXT NOT NULL`
- `title TEXT NOT NULL`
- `content TEXT NOT NULL`
- `updated_at TEXT NOT NULL`

`meta` 表：

- `key TEXT PRIMARY KEY`
- `value TEXT NOT NULL`

`meta.seeded = true` 表示已经写入过种子数据。

## 启动流程

1. `NoteBrowserPage` 创建 SQLite 仓储。
2. 仓储打开数据库并创建表。
3. 如果未写入过种子数据，写入默认文件夹和笔记。
4. 页面进入正常浏览和编辑状态。
5. 新建和编辑笔记直接写入 SQLite。

## 错误处理

数据库初始化期间页面显示加载状态。初始化失败时页面显示错误提示和重试按钮。新建或编辑失败时保留编辑状态，并通过页面提示说明保存失败。

## 测试策略

- 使用临时 SQLite 文件测试首次启动写入种子数据。
- 使用同一个 SQLite 文件重新打开仓储，验证新建笔记可持久保留。
- 验证编辑笔记后重新打开仓储仍能读取新标题和正文。
- 保留现有 widget 测试，通过注入内存仓储覆盖页面交互。

## 文档更新

更新客户端 README、本地运行说明和 Flutter 环境文档，说明当前阶段已经具备 SQLite 本地保存能力，但图片、标签、内部链接和同步仍在后续阶段实现。
