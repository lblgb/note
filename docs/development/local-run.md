# 本地运行说明

> 文件说明：本文档记录客户端和后端的本地运行入口。

## 环境要求

- Git。
- Flutter，用于 Windows 和 Android 客户端。
- Go，用于同步后端。
- PostgreSQL，后续用于服务端主数据库。

Flutter 与 Android 环境配置见：

```text
docs/development/flutter-setup.md
```

## 检查工具

```powershell
git --version
flutter --version
flutter doctor -v
go version
```

## 客户端

客户端目录：

```text
apps/client
```

Windows 运行方式为：

```powershell
Set-Location apps/client
flutter pub get
flutter test
flutter run -d windows
```

Windows 默认连接 `http://127.0.0.1:8080`。如果 API 不在默认地址，使用：

```powershell
flutter run -d windows --dart-define=NOTE_API_BASE_URL=http://127.0.0.1:8080
```

Windows 运行后可验证账号注册、登录、设备登记、Calm Cyan UI 基线、文件夹、笔记列表、详情切换，以及新建、编辑、保存、取消编辑和手动同步。当前阶段文件夹和笔记会写入本地 SQLite，重启应用后仍可读取。

手动同步验证步骤：

```text
1. 启动 Go API。
2. 启动 Windows 客户端并注册或登录。
3. 新建或编辑一条笔记。
4. 点击顶部“同步”。
5. 看到状态变为“已同步：X 文件夹 / Y 笔记”。
6. 用 DB Browser for SQLite 打开 services/api/data/sync.db，查看 sync_folders 和 sync_notes。
```

同步游标保存在客户端本地：

```text
%APPDATA%\NoteClient\sync_cursor.json
```

如果想重新从服务端全量拉取，可以关闭客户端后删除这个文件，再重新启动客户端点击“同步”。

登录态恢复验证方式：

```text
1. 保持客户端打开。
2. 删除或替换服务端 data/auth.db，或者等待访问令牌失效。
3. 点击“同步”。
4. 如果 refresh token 仍有效，客户端会自动刷新令牌并重试。
5. 如果刷新失败，会出现“登录已失效”弹窗。
6. 点击“重新登录”后回到登录页，本地笔记数据不删除。
```

Android 运行方式为：

```powershell
Set-Location apps/client
flutter devices
flutter run -d <android-device-id>
```

Android 模拟器默认连接 `http://10.0.2.2:8080`，用于访问电脑宿主机上的 Go API。Android 真机需要指定电脑局域网 IP：

```powershell
flutter run -d <android-device-id> --dart-define=NOTE_API_BASE_URL=http://电脑局域网IP:8080
```

## 后端

后端目录：

```text
services/api
```

基础服务运行方式为：

```powershell
Set-Location services/api
go test ./...
go run .
```

默认健康检查地址：

```text
http://localhost:8080/health
```

认证数据默认写入：

```text
services/api/data/auth.db
```

同步数据默认写入：

```text
services/api/data/sync.db
```

可用环境变量覆盖数据库位置：

```powershell
$env:NOTE_AUTH_DB="E:\note-data\auth.db"
go run .
```

可用环境变量覆盖同步数据库位置：

```powershell
$env:NOTE_SYNC_DB="E:\note-data\sync.db"
go run .
```
