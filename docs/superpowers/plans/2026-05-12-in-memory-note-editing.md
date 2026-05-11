# In-Memory Note Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-memory create/edit/save/cancel loop to the Flutter note client so users can try the smallest usable note workflow.

**Architecture:** Extend the existing notes feature without adding SQLite or external state management. `NoteRepository` gains write methods, `InMemoryNoteRepository` mutates its runtime note list, and `NoteBrowserPage` manages edit mode with `TextEditingController`s inside its existing `StatefulWidget`.

**Tech Stack:** Flutter, Dart, widget tests, in-memory repository, existing monorepo docs.

---

## File Structure

- Modify: `apps/client/lib/features/notes/data/note_repository.dart` to add create/update methods.
- Modify: `apps/client/lib/features/notes/data/in_memory_note_repository.dart` to support runtime creates and updates.
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart` to add new/edit/save/cancel UI.
- Modify: `apps/client/test/widget_test.dart` to cover create, edit, save, and cancel behavior.
- Modify: `apps/client/README.md`, `docs/development/flutter-setup.md`, and `docs/development/local-run.md` to describe the editable in-memory stage.

## Task 1: Extend Repository Write API

**Files:**
- Modify: `apps/client/lib/features/notes/data/note_repository.dart`
- Modify: `apps/client/lib/features/notes/data/in_memory_note_repository.dart`

- [ ] **Step 1: Update repository interface**

Add these methods to `NoteRepository` after `findNote`:

```dart
  // createNote 在指定文件夹下创建笔记。
  Note createNote({
    required String folderId,
    required String title,
    required String content,
  });

  // updateNote 更新已有笔记，目标不存在时返回 null。
  Note? updateNote({
    required String noteId,
    required String title,
    required String content,
  });
```

Expected final interface:

```dart
// 文件说明：本地笔记读取和写入仓储接口。

import '../domain/folder.dart';
import '../domain/note.dart';

// NoteRepository 定义笔记浏览和编辑所需的数据能力。
abstract interface class NoteRepository {
  // listFolders 返回本地文件夹列表。
  List<Folder> listFolders();

  // listNotes 返回指定文件夹下的笔记列表。
  List<Note> listNotes(String folderId);

  // findNote 根据笔记 ID 查找笔记。
  Note? findNote(String noteId);

  // createNote 在指定文件夹下创建笔记。
  Note createNote({
    required String folderId,
    required String title,
    required String content,
  });

  // updateNote 更新已有笔记，目标不存在时返回 null。
  Note? updateNote({
    required String noteId,
    required String title,
    required String content,
  });
}
```

- [ ] **Step 2: Update in-memory repository constructor**

Change the constructor to accept an optional clock and local ID counter:

```dart
  InMemoryNoteRepository({
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _folders = const [
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
```

Add fields:

```dart
  final DateTime Function() _now;
  final List<Folder> _folders;
  final List<Note> _notes;
  int _nextLocalNoteNumber = 1;
```

- [ ] **Step 3: Add create and update implementation**

Append these methods to `InMemoryNoteRepository`:

```dart
  // createNote 在指定文件夹下创建内存笔记。
  @override
  Note createNote({
    required String folderId,
    required String title,
    required String content,
  }) {
    final note = Note(
      id: 'note-local-${_nextLocalNoteNumber++}',
      folderId: folderId,
      title: title,
      content: content,
      updatedAt: _now(),
    );
    _notes.add(note);
    return note;
  }

  // updateNote 更新内存中的已有笔记。
  @override
  Note? updateNote({
    required String noteId,
    required String title,
    required String content,
  }) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      return null;
    }

    final previous = _notes[index];
    final updated = Note(
      id: previous.id,
      folderId: previous.folderId,
      title: title,
      content: content,
      updatedAt: _now(),
    );
    _notes[index] = updated;
    return updated;
  }
```

- [ ] **Step 4: Run analyzer**

```powershell
Set-Location apps/client
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Commit repository write API**

```powershell
git add apps/client/lib/features/notes/data/note_repository.dart apps/client/lib/features/notes/data/in_memory_note_repository.dart
git commit -m "feat: 添加内存笔记写入能力"
```

Expected: commit succeeds.

## Task 2: Add Editing UI

**Files:**
- Modify: `apps/client/lib/features/notes/presentation/note_browser_page.dart`

- [ ] **Step 1: Add edit state fields**

Inside `_NoteBrowserPageState`, add:

```dart
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isEditing = false;
  bool _isCreating = false;
```

- [ ] **Step 2: Add dispose method**

```dart
  // dispose 释放编辑输入控制器。
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
```

- [ ] **Step 3: Add edit actions**

Add these methods to `_NoteBrowserPageState`:

```dart
  // _startCreateNote 进入新建笔记模式。
  void _startCreateNote() {
    final folderId = _selectedFolderId;
    if (folderId == null) {
      return;
    }

    setState(() {
      _isCreating = true;
      _isEditing = true;
      _titleController.text = '未命名笔记';
      _contentController.text = '';
    });
  }

  // _startEditNote 进入当前笔记编辑模式。
  void _startEditNote(Note note) {
    setState(() {
      _isCreating = false;
      _isEditing = true;
      _titleController.text = note.title;
      _contentController.text = note.content;
    });
  }

  // _saveEditing 保存新建或编辑结果。
  void _saveEditing() {
    final title = _normalizeTitle(_titleController.text);
    final content = _contentController.text.trim();

    if (_isCreating) {
      final folderId = _selectedFolderId;
      if (folderId == null) {
        _cancelEditing();
        return;
      }
      final note = widget.repository.createNote(
        folderId: folderId,
        title: title,
        content: content,
      );
      setState(() {
        _selectedNoteId = note.id;
        _isCreating = false;
        _isEditing = false;
      });
      return;
    }

    final noteId = _selectedNoteId;
    if (noteId == null) {
      _cancelEditing();
      return;
    }

    final updated = widget.repository.updateNote(
      noteId: noteId,
      title: title,
      content: content,
    );
    setState(() {
      _selectedNoteId = updated?.id ?? _selectedNoteId;
      _isEditing = false;
      _isCreating = false;
    });
  }

  // _cancelEditing 取消当前编辑。
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _isCreating = false;
    });
  }
```

Add a top-level helper near `_formatUpdatedAt`:

```dart
// _normalizeTitle 规范化标题，避免保存空标题。
String _normalizeTitle(String value) {
  final title = value.trim();
  return title.isEmpty ? '未命名笔记' : title;
}
```

- [ ] **Step 4: Pass edit state into detail pane**

Replace:

```dart
Expanded(child: _NoteDetailPane(note: selectedNote)),
```

with:

```dart
Expanded(
  child: _NoteDetailPane(
    note: selectedNote,
    isEditing: _isEditing,
    isCreating: _isCreating,
    titleController: _titleController,
    contentController: _contentController,
    onCreate: _startCreateNote,
    onEdit: selectedNote == null ? null : () => _startEditNote(selectedNote),
    onSave: _saveEditing,
    onCancel: _cancelEditing,
  ),
),
```

Also replace the narrow layout `_NoteDetailPane(note: selectedNote)` with the same parameters.

- [ ] **Step 5: Replace `_NoteDetailPane`**

Replace the `_NoteDetailPane` class with:

```dart
// _NoteDetailPane 展示笔记详情或编辑表单。
class _NoteDetailPane extends StatelessWidget {
  const _NoteDetailPane({
    required this.note,
    required this.isEditing,
    required this.isCreating,
    required this.titleController,
    required this.contentController,
    required this.onCreate,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
  });

  final Note? note;
  final bool isEditing;
  final bool isCreating;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final VoidCallback onCreate;
  final VoidCallback? onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  // build 构建详情区、编辑区或空状态。
  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return _NoteEditorPane(
        isCreating: isCreating,
        titleController: titleController,
        contentController: contentController,
        onSave: onSave,
        onCancel: onCancel,
      );
    }

    final note = this.note;
    if (note == null) {
      return _EmptyDetailPane(onCreate: onCreate);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('新建'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              ],
            ),
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
```

- [ ] **Step 6: Add editor and empty detail panes**

Add these widgets before `_EmptyState`:

```dart
// _NoteEditorPane 展示标题和正文编辑表单。
class _NoteEditorPane extends StatelessWidget {
  const _NoteEditorPane({
    required this.isCreating,
    required this.titleController,
    required this.contentController,
    required this.onSave,
    required this.onCancel,
  });

  final bool isCreating;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  // build 构建编辑表单和操作按钮。
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCreating ? '新建笔记' : '编辑笔记',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: '正文',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 8,
              maxLines: 16,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// _EmptyDetailPane 展示空详情区和新建入口。
class _EmptyDetailPane extends StatelessWidget {
  const _EmptyDetailPane({required this.onCreate});

  final VoidCallback onCreate;

  // build 构建空详情区。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('暂无笔记'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run analyzer**

```powershell
Set-Location apps/client
dart format lib test
flutter analyze
```

Expected: formatting succeeds and analyzer reports `No issues found!`.

- [ ] **Step 8: Commit editing UI**

```powershell
git add apps/client/lib/features/notes/presentation/note_browser_page.dart
git commit -m "feat: 添加内存笔记编辑界面"
```

Expected: commit succeeds.

## Task 3: Update Widget Tests

**Files:**
- Modify: `apps/client/test/widget_test.dart`

- [ ] **Step 1: Add create note test**

Append this test inside `main`:

```dart
  testWidgets('新建笔记后展示新内容', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('新建').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '今天的记录');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '这是新建后保存的正文。');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('今天的记录'), findsWidgets);
    expect(find.text('这是新建后保存的正文。'), findsOneWidget);
  });
```

- [ ] **Step 2: Add edit save test**

Append:

```dart
  testWidgets('编辑笔记后更新标题和正文', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '更新后的标题');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '更新后的正文内容。');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('更新后的标题'), findsWidgets);
    expect(find.text('更新后的正文内容。'), findsOneWidget);
  });
```

- [ ] **Step 3: Add cancel test**

Append:

```dart
  testWidgets('取消编辑后保留原内容', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '不会保存的标题');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '不会保存的正文。');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('不会保存的标题'), findsNothing);
    expect(find.text('不会保存的正文。'), findsNothing);
    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsOneWidget);
  });
```

Add this import at the top:

```dart
import 'package:flutter/material.dart';
```

- [ ] **Step 4: Run tests**

```powershell
Set-Location apps/client
dart format test/widget_test.dart
flutter test
```

Expected: all widget tests pass.

- [ ] **Step 5: Commit tests**

```powershell
git add apps/client/test/widget_test.dart
git commit -m "test: 覆盖内存笔记编辑闭环"
```

Expected: commit succeeds.

## Task 4: Update Documentation

**Files:**
- Modify: `apps/client/README.md`
- Modify: `docs/development/flutter-setup.md`
- Modify: `docs/development/local-run.md`

- [ ] **Step 1: Update client README status**

Replace the current status sentence with:

```markdown
当前阶段是内存数据驱动的最小笔记编辑闭环。已支持文件夹列表、笔记列表、笔记详情切换，以及运行期间的新建、编辑、保存和取消编辑。数据暂不写入 SQLite，应用重启后会恢复为种子数据。
```

- [ ] **Step 2: Update Flutter setup docs**

Add this paragraph near the local browser stage note:

```markdown
内存笔记编辑阶段可以通过 Windows 客户端验证新建、编辑、保存和取消编辑。当前阶段只保存到运行期内存，不会写入 SQLite，重启应用后改动会丢失。
```

- [ ] **Step 3: Update local run docs**

Ensure the client run section says that Windows can verify editing:

```markdown
Windows 运行后可验证文件夹、笔记列表、详情切换，以及运行期间的新建、编辑、保存和取消编辑。
```

- [ ] **Step 4: Commit docs**

```powershell
git add apps/client/README.md docs/development/flutter-setup.md docs/development/local-run.md
git commit -m "docs: 更新内存笔记编辑说明"
```

Expected: commit succeeds.

## Task 5: Final Verification And Push

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

Expected: all Go packages pass.

- [ ] **Step 3: Scan for unresolved placeholders**

```powershell
rg -n "T[O]DO|T[B]D|F[I]XME|待[定]" apps/client docs/development docs/superpowers/plans/2026-05-12-in-memory-note-editing.md
```

Expected: no output.

- [ ] **Step 4: Verify git status**

```powershell
git status --short --branch
```

Expected: clean feature branch.

- [ ] **Step 5: Push branch**

```powershell
git push
```

Expected: current branch pushes to upstream, or use `git push -u origin feature/in-memory-note-editing` for a new branch.

## Self-Review

- Spec coverage: tasks cover repository write methods, runtime in-memory mutation, new/edit/save/cancel UI, widget tests, docs, and verification.
- Intentional deferrals: SQLite, delete, folder editing, Markdown preview, images, links, auth, sync, and backend calls are excluded.
- Placeholder scan: plan avoids unresolved implementation placeholders and includes concrete file paths, snippets, commands, and expected results.
