# Local Note Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter local note browser that lets users inspect seeded folders, note lists, and note details on Windows.

**Architecture:** The client adds a small notes feature with domain models, a repository interface, an in-memory repository, and a presentation page. `ShellPage` becomes a thin host for `NoteBrowserPage`; editing, SQLite, Markdown rendering, sync, images, and links remain outside this plan.

**Tech Stack:** Flutter, Dart, widget tests, in-memory data, existing monorepo docs.

---

## File Structure

- Create: `apps/client/lib/features/notes/domain/folder.dart` for the folder model.
- Create: `apps/client/lib/features/notes/domain/note.dart` for the note model.
- Create: `apps/client/lib/features/notes/data/note_repository.dart` for the read-only repository contract.
- Create: `apps/client/lib/features/notes/data/in_memory_note_repository.dart` for deterministic seeded data.
- Create: `apps/client/lib/features/notes/presentation/note_browser_page.dart` for the folder, note list, and detail UI.
- Modify: `apps/client/lib/features/shell/shell_page.dart` to host `NoteBrowserPage`.
- Modify: `apps/client/test/widget_test.dart` to cover default display and selection changes.
- Modify: `apps/client/README.md`, `docs/development/local-run.md`, and `docs/development/flutter-setup.md` to document the first verifiable client stage.

## Task 1: Add Domain Models

**Files:**
- Create: `apps/client/lib/features/notes/domain/folder.dart`
- Create: `apps/client/lib/features/notes/domain/note.dart`
- Test by running: `flutter analyze`

- [ ] **Step 1: Create `folder.dart`**

```dart
// 文件说明：笔记文件夹领域模型。

// Folder 表示客户端本地文件夹。
class Folder {
  const Folder({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
```

- [ ] **Step 2: Create `note.dart`**

```dart
// 文件说明：笔记领域模型。

// Note 表示客户端本地笔记。
class Note {
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String folderId;
  final String title;
  final String content;
  final DateTime updatedAt;
}
```

- [ ] **Step 3: Run analyzer**

```powershell
Set-Location apps/client
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit models**

```powershell
git add apps/client/lib/features/notes/domain
git commit -m "feat: 添加本地笔记领域模型"
```

Expected: commit succeeds.

## Task 2: Add In-Memory Repository

**Files:**
- Create: `apps/client/lib/features/notes/data/note_repository.dart`
- Create: `apps/client/lib/features/notes/data/in_memory_note_repository.dart`
- Test: `apps/client/test/widget_test.dart`

- [ ] **Step 1: Create repository contract**

```dart
// 文件说明：本地笔记读取仓储接口。

import '../domain/folder.dart';
import '../domain/note.dart';

// NoteRepository 定义笔记浏览所需的只读数据能力。
abstract interface class NoteRepository {
  // listFolders 返回本地文件夹列表。
  List<Folder> listFolders();

  // listNotes 返回指定文件夹下的笔记列表。
  List<Note> listNotes(String folderId);

  // findNote 根据笔记 ID 查找笔记。
  Note? findNote(String noteId);
}
```

- [ ] **Step 2: Create seeded repository**

```dart
// 文件说明：本地笔记内存仓储实现。

import '../domain/folder.dart';
import '../domain/note.dart';
import 'note_repository.dart';

// InMemoryNoteRepository 提供可重复的本地种子笔记数据。
class InMemoryNoteRepository implements NoteRepository {
  InMemoryNoteRepository()
    : _folders = const [
        Folder(id: 'folder-inbox', name: '收集箱'),
        Folder(id: 'folder-work', name: '工作'),
        Folder(id: 'folder-life', name: '生活'),
      ],
      _notes = [
        Note(
          id: 'note-welcome',
          folderId: 'folder-inbox',
          title: '欢迎使用轻量同步笔记',
          content: '这是第一条本地种子笔记，用来验证文件夹、列表和详情区的浏览体验。',
          updatedAt: DateTime(2026, 5, 11, 9, 0),
        ),
        Note(
          id: 'note-links',
          folderId: 'folder-inbox',
          title: '后续会支持链接跳转',
          content: '下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。',
          updatedAt: DateTime(2026, 5, 11, 9, 30),
        ),
        Note(
          id: 'note-work-plan',
          folderId: 'folder-work',
          title: '工作计划',
          content: '这里展示工作文件夹下的笔记。当前阶段只读，下一阶段会接入本地编辑保存。',
          updatedAt: DateTime(2026, 5, 11, 10, 0),
        ),
        Note(
          id: 'note-life-list',
          folderId: 'folder-life',
          title: '生活清单',
          content: '这个文件夹用于验证切换文件夹时，笔记列表和详情区会同步更新。',
          updatedAt: DateTime(2026, 5, 11, 10, 30),
        ),
      ];

  final List<Folder> _folders;
  final List<Note> _notes;

  // listFolders 返回种子文件夹列表。
  @override
  List<Folder> listFolders() => List.unmodifiable(_folders);

  // listNotes 返回指定文件夹下按更新时间倒序排列的笔记。
  @override
  List<Note> listNotes(String folderId) {
    final notes = _notes.where((note) => note.folderId == folderId).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(notes);
  }

  // findNote 根据笔记 ID 返回匹配笔记。
  @override
  Note? findNote(String noteId) {
    for (final note in _notes) {
      if (note.id == noteId) {
        return note;
      }
    }
    return null;
  }
}
```

- [ ] **Step 3: Run analyzer**

```powershell
Set-Location apps/client
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit repository**

```powershell
git add apps/client/lib/features/notes/data
git commit -m "feat: 添加本地笔记内存仓储"
```

Expected: commit succeeds.

## Task 3: Build Note Browser UI

**Files:**
- Create: `apps/client/lib/features/notes/presentation/note_browser_page.dart`
- Modify: `apps/client/lib/features/shell/shell_page.dart`
- Test: `apps/client/test/widget_test.dart`

- [ ] **Step 1: Replace shell page with feature host**

Replace `apps/client/lib/features/shell/shell_page.dart`:

```dart
// 文件说明：客户端基础壳页面，挂载当前主要功能页面。

import 'package:flutter/material.dart';

import '../notes/presentation/note_browser_page.dart';

// ShellPage 展示客户端第一阶段主要界面。
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  // build 构建应用壳并挂载本地笔记浏览器。
  @override
  Widget build(BuildContext context) {
    return const NoteBrowserPage();
  }
}
```

- [ ] **Step 2: Create note browser page**

Create `apps/client/lib/features/notes/presentation/note_browser_page.dart` with a stateful page that:

- Uses `InMemoryNoteRepository` by default.
- Defaults to the first folder and first note.
- Displays a three-column layout for width `>= 900`.
- Displays folder chips, note list, and detail area in a vertical layout for narrower widths.
- Shows `暂无文件夹` when no folders exist.
- Shows `暂无笔记` when the selected folder has no notes.

Use this code:

```dart
// 文件说明：本地笔记浏览页面。

import 'package:flutter/material.dart';

import '../data/in_memory_note_repository.dart';
import '../data/note_repository.dart';
import '../domain/folder.dart';
import '../domain/note.dart';

// NoteBrowserPage 展示本地文件夹、笔记列表和笔记详情。
class NoteBrowserPage extends StatefulWidget {
  const NoteBrowserPage({
    super.key,
    NoteRepository? repository,
  }) : repository = repository ?? const _DefaultRepository();

  final NoteRepository repository;

  // createState 创建本地笔记浏览状态。
  @override
  State<NoteBrowserPage> createState() => _NoteBrowserPageState();
}

// _DefaultRepository 延迟创建默认内存仓储。
class _DefaultRepository implements NoteRepository {
  const _DefaultRepository();

  // _repository 返回内存仓储实例。
  static final InMemoryNoteRepository _repository = InMemoryNoteRepository();

  // listFolders 读取默认文件夹列表。
  @override
  List<Folder> listFolders() => _repository.listFolders();

  // listNotes 读取默认文件夹下的笔记列表。
  @override
  List<Note> listNotes(String folderId) => _repository.listNotes(folderId);

  // findNote 读取默认笔记详情。
  @override
  Note? findNote(String noteId) => _repository.findNote(noteId);
}

// _NoteBrowserPageState 管理当前选中的文件夹和笔记。
class _NoteBrowserPageState extends State<NoteBrowserPage> {
  String? _selectedFolderId;
  String? _selectedNoteId;

  // initState 初始化默认选中的文件夹和笔记。
  @override
  void initState() {
    super.initState();
    final folders = widget.repository.listFolders();
    if (folders.isNotEmpty) {
      _selectFolder(folders.first.id, updateState: false);
    }
  }

  // build 构建本地笔记浏览页面。
  @override
  Widget build(BuildContext context) {
    final folders = widget.repository.listFolders();
    final selectedFolderId = _selectedFolderId;
    final notes = selectedFolderId == null
        ? <Note>[]
        : widget.repository.listNotes(selectedFolderId);
    final selectedNote =
        _selectedNoteId == null ? null : widget.repository.findNote(_selectedNoteId!);

    return Scaffold(
      appBar: AppBar(title: const Text('轻量同步笔记')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (folders.isEmpty) {
            return const _EmptyState(message: '暂无文件夹');
          }

          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return Row(
              children: [
                _FolderPane(
                  folders: folders,
                  selectedFolderId: selectedFolderId,
                  onFolderSelected: _selectFolder,
                ),
                const VerticalDivider(width: 1),
                _NoteListPane(
                  notes: notes,
                  selectedNoteId: _selectedNoteId,
                  onNoteSelected: _selectNote,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _NoteDetailPane(note: selectedNote)),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FolderStrip(
                folders: folders,
                selectedFolderId: selectedFolderId,
                onFolderSelected: _selectFolder,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: _NoteListPane(
                  notes: notes,
                  selectedNoteId: _selectedNoteId,
                  onNoteSelected: _selectNote,
                ),
              ),
              const SizedBox(height: 16),
              _NoteDetailPane(note: selectedNote),
            ],
          );
        },
      ),
    );
  }

  // _selectFolder 切换文件夹并自动选择第一条笔记。
  void _selectFolder(String folderId, {bool updateState = true}) {
    final notes = widget.repository.listNotes(folderId);
    final nextNoteId = notes.isEmpty ? null : notes.first.id;

    if (updateState) {
      setState(() {
        _selectedFolderId = folderId;
        _selectedNoteId = nextNoteId;
      });
      return;
    }

    _selectedFolderId = folderId;
    _selectedNoteId = nextNoteId;
  }

  // _selectNote 切换当前笔记。
  void _selectNote(String noteId) {
    setState(() {
      _selectedNoteId = noteId;
    });
  }
}

// _FolderPane 展示宽屏文件夹侧边栏。
class _FolderPane extends StatelessWidget {
  const _FolderPane({
    required this.folders,
    required this.selectedFolderId,
    required this.onFolderSelected,
  });

  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String> onFolderSelected;

  // build 构建文件夹列表。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('文件夹', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final folder in folders)
            ListTile(
              selected: folder.id == selectedFolderId,
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              onTap: () => onFolderSelected(folder.id),
            ),
        ],
      ),
    );
  }
}

// _FolderStrip 展示窄屏文件夹横向选择器。
class _FolderStrip extends StatelessWidget {
  const _FolderStrip({
    required this.folders,
    required this.selectedFolderId,
    required this.onFolderSelected,
  });

  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String> onFolderSelected;

  // build 构建文件夹筛选芯片。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final folder in folders)
          ChoiceChip(
            label: Text(folder.name),
            selected: folder.id == selectedFolderId,
            onSelected: (_) => onFolderSelected(folder.id),
          ),
      ],
    );
  }
}

// _NoteListPane 展示当前文件夹下的笔记列表。
class _NoteListPane extends StatelessWidget {
  const _NoteListPane({
    required this.notes,
    required this.selectedNoteId,
    required this.onNoteSelected,
  });

  final List<Note> notes;
  final String? selectedNoteId;
  final ValueChanged<String> onNoteSelected;

  // build 构建笔记列表或空状态。
  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const _EmptyState(message: '暂无笔记');
    }

    return SizedBox(
      width: 320,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final note = notes[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              selected: note.id == selectedNoteId,
              title: Text(note.title),
              subtitle: Text(_formatUpdatedAt(note.updatedAt)),
              onTap: () => onNoteSelected(note.id),
            ),
          );
        },
      ),
    );
  }
}

// _NoteDetailPane 展示笔记详情。
class _NoteDetailPane extends StatelessWidget {
  const _NoteDetailPane({required this.note});

  final Note? note;

  // build 构建详情区或空状态。
  @override
  Widget build(BuildContext context) {
    final note = this.note;
    if (note == null) {
      return const _EmptyState(message: '暂无笔记');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '更新于 ${_formatUpdatedAt(note.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text(note.content, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

// _EmptyState 展示空数据提示。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  // build 构建居中的空状态文本。
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

// _formatUpdatedAt 格式化笔记更新时间。
String _formatUpdatedAt(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
```

- [ ] **Step 3: Run analyzer**

```powershell
Set-Location apps/client
dart format lib test
flutter analyze
```

Expected: formatting succeeds and analyzer reports `No issues found!`.

- [ ] **Step 4: Commit browser UI**

```powershell
git add apps/client/lib/features/shell/shell_page.dart apps/client/lib/features/notes/presentation/note_browser_page.dart
git commit -m "feat: 添加本地笔记浏览界面"
```

Expected: commit succeeds.

## Task 4: Update Widget Tests

**Files:**
- Modify: `apps/client/test/widget_test.dart`

- [ ] **Step 1: Replace widget tests**

```dart
// 文件说明：客户端本地笔记浏览器组件测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/app/note_app.dart';

// main 注册客户端本地笔记浏览器组件测试。
void main() {
  testWidgets('默认展示第一条种子笔记', (tester) async {
    await tester.pumpWidget(const NoteApp());

    expect(find.text('轻量同步笔记'), findsOneWidget);
    expect(find.text('收集箱'), findsOneWidget);
    expect(find.text('后续会支持链接跳转'), findsOneWidget);
    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsOneWidget);
  });

  testWidgets('点击文件夹后切换笔记列表和详情', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    expect(find.text('工作计划'), findsOneWidget);
    expect(find.text('这里展示工作文件夹下的笔记。当前阶段只读，下一阶段会接入本地编辑保存。'), findsOneWidget);
  });

  testWidgets('点击笔记后切换详情', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('欢迎使用轻量同步笔记'));
    await tester.pumpAndSettle();

    expect(find.text('这是第一条本地种子笔记，用来验证文件夹、列表和详情区的浏览体验。'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests**

```powershell
Set-Location apps/client
dart format test/widget_test.dart
flutter test
```

Expected: all widget tests pass.

- [ ] **Step 3: Commit tests**

```powershell
git add apps/client/test/widget_test.dart
git commit -m "test: 覆盖本地笔记浏览交互"
```

Expected: commit succeeds.

## Task 5: Update Documentation

**Files:**
- Modify: `apps/client/README.md`
- Modify: `docs/development/local-run.md`
- Modify: `docs/development/flutter-setup.md`

- [ ] **Step 1: Update `apps/client/README.md` status**

Ensure the current status section says:

```markdown
当前阶段是可查看种子数据的本地笔记浏览器。已支持文件夹列表、笔记列表和笔记详情切换。笔记编辑、本地 SQLite 保存、账号 UI 和同步功能将在后续计划中实现。
```

- [ ] **Step 2: Update local run docs**

Ensure `docs/development/local-run.md` client section includes:

```powershell
Set-Location apps/client
flutter pub get
flutter test
flutter run -d windows
```

- [ ] **Step 3: Update Flutter setup docs**

Ensure `docs/development/flutter-setup.md` explains:

```markdown
本地笔记浏览器阶段可以通过 Windows 客户端验证文件夹、笔记列表和笔记详情切换。当前阶段使用内存种子数据，不会写入 SQLite。
```

- [ ] **Step 4: Commit docs**

```powershell
git add apps/client/README.md docs/development/local-run.md docs/development/flutter-setup.md
git commit -m "docs: 更新本地笔记浏览器说明"
```

Expected: commit succeeds.

## Task 6: Final Verification And Push

**Files:**
- Read all changed files.

- [ ] **Step 1: Run Flutter verification**

```powershell
Set-Location apps/client
flutter pub get
flutter analyze
flutter test
```

Expected: all commands pass.

- [ ] **Step 2: Run Go verification**

```powershell
Set-Location services/api
go test -count=1 ./...
```

Expected: all packages pass.

- [ ] **Step 3: Scan for unresolved placeholders**

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]" apps/client docs/development docs/superpowers/plans/2026-05-11-local-note-browser.md
```

Expected: no output.

- [ ] **Step 4: Push branch**

```powershell
git push
```

Expected: branch pushes to upstream, or use `git push -u origin feature/local-note-browser` if this is a new branch.

## Self-Review

- Spec coverage: tasks cover domain models, repository, seeded data, folder/list/detail UI, empty states, tests, docs, and verification.
- Intentional deferrals: editing, SQLite, Markdown rendering, image handling, links, auth, sync, and backend calls are excluded.
- Placeholder scan: plan avoids unresolved implementation placeholders and gives exact file paths, code, commands, and expected results.
