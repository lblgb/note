# Go 同步后端

> 文件说明：本文档说明 Go 同步后端的职责和本地运行方式。

本服务负责账号认证、设备登记、变更同步和附件上传下载。当前阶段提供健康检查、账号注册、登录、刷新令牌、退出登录和设备登记。

## 本地运行

```powershell
go test ./...
go run .
```

## 健康检查

```text
GET /health
```

成功响应：

```json
{"status":"ok"}
```

## 账号与设备接口

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
POST /api/devices/register
```

详细接口文档见：

```text
docs/api/auth-device.md
```
