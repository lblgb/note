# Flutter Client Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the Flutter client foundation under `apps/client`, verify Windows desktop runs, and document the client development workflow.

**Architecture:** The Flutter client remains a separate app inside the monorepo at `apps/client`. This stage only creates the application shell, routes, theme, and a health-check style home screen; note editing, SQLite, sync, auth UI, and API integration are intentionally deferred. If Flutter is not installed or not on `PATH`, this plan stops after documenting the environment blocker.

**Tech Stack:** Flutter stable, Dart, Windows desktop target, Flutter widget tests, PowerShell, Git.

---

## File Structure

This plan creates or modifies:

- Modify: `apps/client/README.md` with real Flutter setup and run instructions.
- Create by Flutter tooling: `apps/client/pubspec.yaml`, `apps/client/lib/main.dart`, `apps/client/test/widget_test.dart`, and generated Flutter platform files.
- Create: `apps/client/lib/app/note_app.dart` for the root app widget.
- Create: `apps/client/lib/app/app_theme.dart` for theme configuration.
- Create: `apps/client/lib/features/shell/shell_page.dart` for the first usable shell screen.
- Create: `docs/development/flutter-setup.md` for local Flutter environment setup and verification.
- Modify: `docs/development/local-run.md` to link the Flutter setup doc and client run commands.

Do not implement note CRUD, login screens, local database, sync, image handling, or Markdown editing in this plan.

## Task 1: Verify Flutter Environment

**Files:**
- Create: `docs/development/flutter-setup.md`

- [ ] **Step 1: Check Flutter availability**

Run:

```powershell
flutter --version
```

Expected if ready: Flutter version information prints successfully.

Expected in the current environment before setup: command fails with `flutter` not recognized.

- [ ] **Step 2: If Flutter is unavailable, write setup blocker documentation**

Create `docs/development/flutter-setup.md`:

```markdown
# Flutter 环境配置

> 文件说明：本文档记录 Flutter 客户端开发所需环境和检查命令。

## 当前要求

- Flutter stable。
- Windows desktop 支持。
- Android SDK，后续用于 Android 客户端。

## 检查命令

```powershell
flutter --version
flutter doctor
flutter devices
```

## Windows 桌面支持

启用 Windows 桌面支持：

```powershell
flutter config --enable-windows-desktop
flutter doctor
```

## 当前阻塞

如果 `flutter --version` 提示 `flutter` 不可识别，说明 Flutter 未安装或未加入 `PATH`。需要先安装 Flutter，并确保新的终端可以直接执行 `flutter --version`。
```

- [ ] **Step 3: Commit environment documentation if Flutter is unavailable**

Run:

```powershell
git add docs/development/flutter-setup.md
git commit -m "docs: 添加 Flutter 环境配置说明"
```

Expected: commit succeeds.

Stop this plan here until Flutter is available. Do not create a Flutter project without a working `flutter` command.

## Task 2: Scaffold Flutter Client

**Files:**
- Modify/Create by command: `apps/client/*`

- [ ] **Step 1: Verify Flutter is available**

Run:

```powershell
flutter --version
flutter doctor
```

Expected: both commands succeed. `flutter doctor` may show Android toolchain warnings, but Windows desktop must be available for this plan.

- [ ] **Step 2: Backup existing placeholder README**

Run:

```powershell
Get-Content -Raw apps/client/README.md
```

Expected: existing placeholder README is readable.

- [ ] **Step 3: Scaffold Flutter app**

Run from repository root:

```powershell
flutter create --platforms=windows,android --project-name note_client apps/client
```

Expected: Flutter project files are created under `apps/client`.

- [ ] **Step 4: Restore Chinese client README**

Replace `apps/client/README.md` with:

```markdown
# Flutter 客户端

> 文件说明：本文档说明 Flutter 客户端的职责、当前状态和本地运行入口。

客户端负责 Windows 和 Android 端的笔记编辑、文件夹管理、图片附件、外部链接、内部笔记链接、本地离线存储和同步状态展示。

## 当前状态

当前阶段是 Flutter 客户端基础壳。已创建 Flutter 工程、应用入口、基础主题和首页壳。笔记业务、本地数据库、账号 UI 和同步功能将在后续计划中实现。

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
```

- [ ] **Step 5: Run generated tests**

Run:

```powershell
Set-Location apps/client
flutter test
```

Expected: generated Flutter widget test passes or fails only because default template text will be replaced in the next task.

- [ ] **Step 6: Commit scaffold**

Run:

```powershell
git add apps/client
git commit -m "chore: 创建 Flutter 客户端工程"
```

Expected: commit succeeds.

## Task 3: Add Client App Shell

**Files:**
- Modify: `apps/client/lib/main.dart`
- Create: `apps/client/lib/app/note_app.dart`
- Create: `apps/client/lib/app/app_theme.dart`
- Create: `apps/client/lib/features/shell/shell_page.dart`

- [ ] **Step 1: Write app theme**

Create `apps/client/lib/app/app_theme.dart`:

```dart
// 文件说明：客户端应用主题配置。
import 'package:flutter/material.dart';

// buildAppTheme 创建应用基础主题。
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}
```

- [ ] **Step 2: Write root app widget**

Create `apps/client/lib/app/note_app.dart`:

```dart
// 文件说明：客户端应用根组件。
import 'package:flutter/material.dart';

import '../features/shell/shell_page.dart';
import 'app_theme.dart';

// NoteApp 是 Flutter 客户端根组件。
class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '轻量同步笔记',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ShellPage(),
    );
  }
}
```

- [ ] **Step 3: Write shell page**

Create `apps/client/lib/features/shell/shell_page.dart`:

```dart
// 文件说明：客户端基础壳页面，展示后续笔记工作区入口。
import 'package:flutter/material.dart';

// ShellPage 展示客户端第一阶段基础界面。
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('轻量同步笔记')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return const Row(
              children: [
                _SidebarPane(),
                VerticalDivider(width: 1),
                Expanded(child: _WorkspacePane()),
              ],
            );
          }
          return const _WorkspacePane();
        },
      ),
    );
  }
}

// _SidebarPane 展示桌面端侧边栏占位。
class _SidebarPane extends StatelessWidget {
  const _SidebarPane();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('文件夹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          ListTile(leading: Icon(Icons.folder_outlined), title: Text('全部笔记')),
          ListTile(leading: Icon(Icons.history), title: Text('最近编辑')),
        ],
      ),
    );
  }
}

// _WorkspacePane 展示当前阶段工作区占位。
class _WorkspacePane extends StatelessWidget {
  const _WorkspacePane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '客户端基础壳已就绪',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '下一阶段将接入本地笔记数据、文件夹和 Markdown 编辑体验。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update main entry**

Replace `apps/client/lib/main.dart`:

```dart
// 文件说明：Flutter 客户端入口。
import 'package:flutter/material.dart';

import 'app/note_app.dart';

// main 启动 Flutter 客户端。
void main() {
  runApp(const NoteApp());
}
```

- [ ] **Step 5: Format and analyze**

Run:

```powershell
Set-Location apps/client
dart format lib test
flutter analyze
```

Expected: formatting succeeds and analyze reports no issues.

- [ ] **Step 6: Commit app shell**

Run:

```powershell
git add apps/client/lib
git commit -m "feat: 添加 Flutter 客户端基础壳"
```

Expected: commit succeeds.

## Task 4: Update Widget Test

**Files:**
- Modify: `apps/client/test/widget_test.dart`

- [ ] **Step 1: Replace widget test**

Replace `apps/client/test/widget_test.dart`:

```dart
// 文件说明：客户端基础壳组件测试。
import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/app/note_app.dart';

// main 注册客户端基础壳组件测试。
void main() {
  testWidgets('显示客户端基础壳标题', (tester) async {
    await tester.pumpWidget(const NoteApp());

    expect(find.text('轻量同步笔记'), findsOneWidget);
    expect(find.text('客户端基础壳已就绪'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests**

Run:

```powershell
Set-Location apps/client
dart format test/widget_test.dart
flutter test
```

Expected: tests pass.

- [ ] **Step 3: Commit widget test**

Run:

```powershell
git add apps/client/test/widget_test.dart
git commit -m "test: 添加 Flutter 客户端基础壳测试"
```

Expected: commit succeeds.

## Task 5: Update Development Docs

**Files:**
- Modify: `docs/development/local-run.md`
- Modify: `docs/development/flutter-setup.md`

- [ ] **Step 1: Update local run docs**

Ensure `docs/development/local-run.md` contains this client section:

```markdown
## 客户端

客户端目录：

```text
apps/client
```

Flutter 环境配置见：

```text
docs/development/flutter-setup.md
```

Windows 运行方式为：

```powershell
Set-Location apps/client
flutter pub get
flutter test
flutter run -d windows
```

Android 运行方式为：

```powershell
Set-Location apps/client
flutter devices
flutter run -d <android-device-id>
```
```

- [ ] **Step 2: Update Flutter setup docs**

Ensure `docs/development/flutter-setup.md` includes:

```markdown
## 项目验证

```powershell
Set-Location apps/client
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```
```

- [ ] **Step 3: Commit docs**

Run:

```powershell
git add docs/development/local-run.md docs/development/flutter-setup.md apps/client/README.md
git commit -m "docs: 更新 Flutter 客户端运行说明"
```

Expected: commit succeeds.

## Task 6: Full Client Verification And Push

**Files:**
- Read all files changed by this plan.

- [ ] **Step 1: Run Flutter verification**

Run:

```powershell
Set-Location apps/client
flutter pub get
flutter analyze
flutter test
```

Expected: all commands pass.

- [ ] **Step 2: Run Go verification**

Run:

```powershell
Set-Location services/api
go test -count=1 ./...
```

Expected: all Go tests pass.

- [ ] **Step 3: Scan for unresolved placeholders**

Run:

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]|以[后]再说" apps/client docs/development docs/superpowers/plans/2026-05-10-flutter-client-foundation.md
```

Expected: no output.

- [ ] **Step 4: Verify git status**

Run:

```powershell
git status --short
```

Expected: no output after all task commits.

- [ ] **Step 5: Push branch**

Run:

```powershell
git push
```

Expected: current branch pushes to its upstream. If this plan is executed from a new feature branch, use `git push -u origin <branch-name>`.

---

## Self-Review

- Spec coverage: this plan covers Flutter environment verification, project scaffolding, Windows-ready client shell, widget test, run docs, and full verification.
- Intentional deferrals: login UI, API calls, SQLite, folders, notes, Markdown editor, image handling, internal note links, Android device validation, and sync are excluded.
- Environment blocker: current local check shows `flutter` is not recognized, so Task 1 may be the only executable task until Flutter is installed or added to `PATH`.
- Placeholder scan: this plan avoids unresolved placeholder wording and provides exact commands, file paths, and code.
