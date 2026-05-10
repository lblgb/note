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

Flutter 项目创建后，Windows 运行方式为：

```powershell
Set-Location apps/client
flutter pub get
flutter run -d windows
```

Android 运行方式为：

```powershell
Set-Location apps/client
flutter devices
flutter run -d <android-device-id>
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
