# Flutter 客户端

> 文件说明：本文档说明 Flutter 客户端的职责、当前状态和本地运行入口。

客户端负责 Windows 和 Android 端的笔记编辑、文件夹管理、图片附件、外部链接、内部笔记链接、本地离线存储和同步状态展示。

## 当前状态

当前阶段是 SQLite 数据驱动的最小笔记编辑闭环，并已接入账号注册、登录、退出、本地会话保存和登录后当前设备登记。已支持文件夹列表、笔记列表、笔记详情切换，以及新建、编辑、保存和取消编辑。文件夹和笔记会保存到本地 SQLite，应用重启后仍可读取。

界面已切换到 Calm Cyan UI 基线：Windows 端使用顶部工具栏、文件夹侧栏、笔记列表和文档式详情编辑区；窄屏端保留同一视觉语言并使用单列布局。

## 本地运行

先启动 API 服务：

```powershell
Set-Location services/api
go run .
```

客户端默认按平台选择 API 地址：

- Windows 和桌面端：`http://127.0.0.1:8080`。
- Android 模拟器：`http://10.0.2.2:8080`。

真机调试或后端不在默认地址时，用 `NOTE_API_BASE_URL` 覆盖：

```powershell
Set-Location apps/client
flutter pub get
flutter test
flutter run -d windows
flutter run -d windows --dart-define=NOTE_API_BASE_URL=http://127.0.0.1:8080
flutter run -d <android-device-id> --dart-define=NOTE_API_BASE_URL=http://电脑局域网IP:8080
```

启动后先注册或登录账号，认证成功后客户端会调用 `/api/devices/register` 登记当前设备，再进入本地笔记界面。退出登录会清除本地 `auth_session.json` 并回到登录页。

## 计划能力

- Android 分层导航布局。
- 图片附件插入和展示。
- 外部链接跳转。
- 同步队列和同步状态。
