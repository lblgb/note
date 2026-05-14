# Go 同步后端

> 文件说明：本文档说明 Go 同步后端的职责和本地运行方式。

本服务负责账号认证、设备登记、变更同步和附件上传下载。当前阶段提供健康检查、账号注册、登录、刷新令牌、退出登录和设备登记。

## 本地运行

```powershell
go test ./...
go run .
```

默认情况下，账号、刷新令牌和设备登记会写入当前目录下的 SQLite 数据库：

```text
data/auth.db
```

可以用环境变量覆盖认证数据库路径：

```powershell
$env:NOTE_AUTH_DB="E:\note-data\auth.db"
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
