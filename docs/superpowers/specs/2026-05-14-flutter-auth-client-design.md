# Flutter Auth Client Design

> 文件说明：记录 Flutter 客户端账号注册、登录、退出和本地会话保存的设计。

## 背景

客户端已经具备本地 SQLite 笔记、Markdown 预览和笔记内链。服务端已经提供账号注册、登录、刷新令牌、退出登录和设备登记接口。本阶段只接入账号入口闭环，让用户可以注册、登录后进入笔记页面，并在退出后回到认证页面。

## 目标

- Flutter 客户端支持注册账号。
- Flutter 客户端支持登录账号。
- 登录或注册成功后保存用户信息、访问令牌和刷新令牌。
- 应用启动时读取本地会话；有会话进入笔记页，无会话进入认证页。
- 笔记页提供退出登录入口，退出后清除本地会话并回到认证页。
- API 地址可配置，默认使用 `http://127.0.0.1:8080`。
- Windows 和 Android 使用同一套认证逻辑。

## 非目标

- 不实现自动刷新访问令牌。
- 不实现设备登记。
- 不实现笔记同步。
- 不实现密码找回、邮箱验证、第三方登录。
- 不把 token 写入 SQLite 笔记库。

## 架构

认证功能拆成四层：

- 数据模型：`AuthUser` 和 `AuthSession` 表示服务端认证响应和本地会话。
- API 客户端：`AuthApiClient` 用 `dart:io` 的 `HttpClient` 发送 JSON 请求，解析服务端成功响应和错误响应。
- 会话存储：`AuthSessionStore` 抽象会话读写；默认实现 `FileAuthSessionStore` 把 JSON 写到应用支持目录下的 `auth_session.json`。
- UI 控制：`AuthGate` 启动时加载会话，未登录显示 `AuthPage`，已登录显示 `ShellPage`；退出登录时调用 API 后清理本地会话。

`NoteApp` 继续作为根组件，新增可注入的 `AuthApiClient` 和 `AuthSessionStore` 方便测试。现有 `NoteBrowserPage` 不承担认证逻辑，只接收一个可选的退出登录回调，负责在顶部工具栏显示退出按钮。

## 数据流

启动：

1. `NoteApp` 创建默认 API 客户端和会话存储。
2. `AuthGate` 调用 `sessionStore.load()`。
3. 返回 `null` 时显示 `AuthPage`。
4. 返回 `AuthSession` 时显示 `ShellPage`。

登录：

1. 用户输入邮箱和密码。
2. `AuthPage` 调用 `authApiClient.login()`。
3. 成功后 `AuthGate` 保存 session 并切换到 `ShellPage`。
4. 失败时在表单上显示服务端错误信息。

注册：

1. 用户切换到注册模式，输入邮箱、显示名称和密码。
2. `AuthPage` 调用 `authApiClient.register()`。
3. 成功后保存 session 并进入笔记页。

退出：

1. 用户在笔记页点击退出。
2. `AuthGate` 调用 `authApiClient.logout(refreshToken)`。
3. 不论服务端退出是否成功，客户端都会清理本地 session 并返回认证页。

## 错误处理

- 网络异常显示 `无法连接服务器，请检查 API 地址或服务状态`。
- 服务端 JSON 错误优先显示 `error.message`。
- 非 2xx 且没有标准错误结构时显示 `请求失败，请稍后重试`。
- 会话文件损坏时按未登录处理，并覆盖为未登录状态。

## 配置

默认 API 地址为 `http://127.0.0.1:8080`。为了便于后续调试，`AuthApiClient` 构造函数接收 `baseUrl`，测试和 Android 调试可以注入不同地址。Android 模拟器访问宿主机时可使用 `http://10.0.2.2:8080`。

## 测试

- `AuthApiClient` 单测覆盖注册、登录、服务端错误和网络错误。
- `AuthSessionStore` 单测覆盖保存、读取、清除和损坏 JSON。
- `AuthGate` 组件测试覆盖无会话显示登录页、有会话进入笔记页、登录成功切换、退出后回到登录页。
- 现有笔记组件测试继续通过。

## 验收

- 本地启动 API 后，客户端可以注册新账号并进入笔记页。
- 客户端可以用已注册账号登录并进入笔记页。
- 重新启动应用后仍保持登录状态。
- 点击退出登录后回到认证页。
- `flutter test` 和 `flutter analyze` 通过。
