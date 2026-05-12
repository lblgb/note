# Flutter 客户端

> 文件说明：本文档说明 Flutter 客户端的职责、当前状态和本地运行入口。

客户端负责 Windows 和 Android 端的笔记编辑、文件夹管理、图片附件、外部链接、内部笔记链接、本地离线存储和同步状态展示。

## 当前状态

当前阶段是内存数据驱动的最小笔记编辑闭环。已支持文件夹列表、笔记列表、笔记详情切换，以及运行期间的新建、编辑、保存和取消编辑。数据暂不写入 SQLite，应用重启后会恢复为种子数据。

## 本地运行

```powershell
Set-Location apps/client
flutter pub get
flutter test
flutter run -d windows
```

## 计划能力

- Windows 三栏布局。
- Android 分层导航布局。
- Markdown 编辑和预览。
- 图片附件插入和展示。
- 外部链接跳转。
- 内部笔记链接跳转。
- SQLite 本地数据层。
- 同步队列和同步状态。
