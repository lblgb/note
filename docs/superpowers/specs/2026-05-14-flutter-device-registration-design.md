# Flutter Device Registration Design

> 文件说明：记录 Flutter 客户端登录后自动登记当前设备的设计。

## 背景

客户端已经具备注册、登录、退出和本地会话保存能力。服务端已经提供 `POST /api/devices/register` 接口，并要求使用 `Authorization: Bearer <accessToken>`。在进入笔记同步之前，需要先把当前 Windows 或 Android 设备登记到账号下，后续同步才能基于设备身份扩展同步游标和冲突处理。

## 目标

- 登录或注册成功后自动登记当前设备。
- Windows 客户端登记为 `deviceName: Windows 设备`、`platform: windows`。
- Android 客户端登记为 `deviceName: Android 设备`、`platform: android`。
- 服务端返回的设备信息保存进本地 `AuthSession`。
- 退出登录仍然清除本地会话。

## 非目标

- 不实现设备列表管理。
- 不实现设备重命名。
- 不实现同步游标、笔记同步或冲突处理。
- 不调整服务端设备 API。

## 设计

`AuthApiClient` 新增 `registerDevice` 方法，负责向 `/api/devices/register` 发送设备名、平台和访问令牌。`AuthSession` 新增可选 `AuthDevice` 字段，用于保存登记后的 `deviceId`、`userId`、设备名和平台。

`AuthGate` 在登录或注册成功后读取当前平台设备画像，调用 `registerDevice`，成功后把带设备信息的 session 写入 `AuthSessionStore`。设备登记失败时保持在登录页并显示 API 错误，不保存半完成 session。

## 验收

- 登录成功后会调用 `/api/devices/register`。
- 请求头包含 `Authorization: Bearer <accessToken>`。
- 本地 session JSON 中包含 `device` 字段。
- `flutter test` 和 `flutter analyze` 通过。
