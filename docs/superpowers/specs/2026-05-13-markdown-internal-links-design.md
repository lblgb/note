# Markdown Internal Links Design

> 文件说明：记录 Flutter 笔记端 Markdown 预览和笔记内链跳转的产品与技术约束。

## 背景

当前 Flutter 客户端已经具备本地文件夹、笔记列表、笔记详情、编辑保存和 SQLite 持久化能力。下一步需要让详情区从纯文本阅读升级为 Markdown 预览，并允许用户在笔记内容中跳转到其他笔记。

## 目标

- 详情区渲染 Markdown 基础语法，包括标题、粗体、斜体、列表、引用、代码块和普通链接文本。
- 支持 `[[标题]]` 形式的笔记标题内链。
- 支持 `[标题](note:note-id)` 形式的笔记 ID 内链。
- 点击有效内链时切换到目标笔记所在文件夹和目标笔记详情。
- 点击失效内链时用轻提示显示 `未找到笔记`。
- 普通外部链接本阶段不拉起系统浏览器，只保留可识别链接展示和轻提示。

## 非目标

- 不实现图片渲染和上传。
- 不实现外部链接系统浏览器跳转。
- 不实现链接自动补全、反向链接、链接索引表。
- 不重构现有 SQLite 表结构。

## 设计

新增一个独立的链接解析服务，负责把 `[[标题]]` 预处理为 Markdown 链接，并负责将 `note:` 和 `note-title:` 链接解析为目标笔记。UI 详情区使用 `flutter_markdown_plus` 渲染 Markdown，点击链接时调用解析服务，解析成功后通过页面状态切换当前文件夹和笔记。

`[[标题]]` 使用精确标题匹配。存在多个同名笔记时，选择 `updatedAt` 最新的一条，保持用户最近编辑的笔记优先。`note:note-id` 使用 ID 精确匹配，优先级高于标题链接。

## 文件边界

- `apps/client/lib/features/notes/application/note_link_resolver.dart`：链接预处理和目标笔记解析。
- `apps/client/lib/features/notes/presentation/markdown_note_body.dart`：Markdown 详情渲染和点击事件桥接。
- `apps/client/lib/features/notes/presentation/note_browser_page.dart`：传入仓储和内链打开回调。
- `apps/client/test/features/notes/application/note_link_resolver_test.dart`：解析规则单元测试。
- `apps/client/test/widget_test.dart`：覆盖详情 Markdown 预览和内链跳转的界面行为。
- `apps/client/pubspec.yaml` / `apps/client/pubspec.lock`：引入 Markdown 渲染依赖。

## 验收

- `flutter test` 全部通过。
- `[[工作计划]]` 能跳转到标题为 `工作计划` 的最新笔记。
- `[工作计划](note:note-work-plan)` 能按 ID 跳转。
- 找不到目标笔记时显示 `未找到笔记`。
- 编辑区仍然保留原始 Markdown 文本，不自动改写用户内容。
