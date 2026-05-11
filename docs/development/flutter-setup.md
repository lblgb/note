# Flutter 与 Android 环境配置

> 文件说明：本文档记录 Flutter 客户端开发所需的本机环境、路径配置和检查命令。

## 当前环境

- Flutter SDK：`E:\tools\flutter`
- Dart：随 Flutter SDK 安装。
- JDK 17：`E:\tools\jdk-17`
- Android SDK：`E:\tools\android-sdk`
- Android 平台：`android-36`
- Android Build Tools：`36.0.0`
- Android Platform Tools：`37.0.0`
- Windows 构建工具：Visual Studio Build Tools 2022，路径 `C:\BuildTools`

## 用户环境变量

需要确保新终端可以读取以下用户环境变量：

```powershell
$env:JAVA_HOME
$env:ANDROID_HOME
$env:ANDROID_SDK_ROOT
$env:PUB_HOSTED_URL
$env:FLUTTER_STORAGE_BASE_URL
```

当前推荐值：

```powershell
JAVA_HOME=E:\tools\jdk-17
ANDROID_HOME=E:\tools\android-sdk
ANDROID_SDK_ROOT=E:\tools\android-sdk
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

`Path` 至少需要包含：

```powershell
E:\tools\flutter\bin
E:\tools\jdk-17\bin
E:\tools\android-sdk\cmdline-tools\latest\bin
E:\tools\android-sdk\platform-tools
E:\tools\android-sdk\emulator
```

## 检查命令

```powershell
flutter --version
flutter doctor -v
adb version
sdkmanager --sdk_root=E:\tools\android-sdk --list_installed
```

## 项目验证

本地笔记浏览器阶段可以通过 Windows 客户端验证文件夹、笔记列表和笔记详情切换。当前阶段使用内存种子数据，不会写入 SQLite。

```powershell
Set-Location apps/client
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

## 已知说明

- Android Studio 安装器在当前环境中无法申请管理员权限，因此本机采用免管理员的 Android Command Line Tools 方案。
- `flutter doctor -v` 中 Chrome 检查失败不影响 Windows 和 Android 客户端开发。
- `flutter doctor -v` 的网络资源检查可能因为 `maven.google.com` 连接超时而提示警告；如果后续 Android 构建下载 Gradle 依赖失败，需要再为 Gradle 配置 Maven 镜像。
