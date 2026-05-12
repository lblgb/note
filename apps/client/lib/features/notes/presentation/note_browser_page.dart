// 文件说明：本地笔记浏览、编辑和默认 SQLite 仓储初始化页面。
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/note_repository.dart';
import '../data/sqlite_note_repository.dart';
import '../domain/folder.dart';
import '../domain/note.dart';

// NoteBrowserPage 展示本地文件夹、笔记列表、笔记详情和编辑入口。
class NoteBrowserPage extends StatefulWidget {
  const NoteBrowserPage({super.key, this.repository, this.repositoryFactory});

  final NoteRepository? repository;
  final Future<NoteRepository> Function()? repositoryFactory;

  // createState 创建本地笔记浏览和编辑状态。
  @override
  State<NoteBrowserPage> createState() => _NoteBrowserPageState();
}

// _NoteBrowserPageState 管理仓储加载、当前选中文件夹、笔记和编辑状态。
class _NoteBrowserPageState extends State<NoteBrowserPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  NoteRepository? _repository;
  Object? _loadError;
  String? _selectedFolderId;
  String? _selectedNoteId;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isCreating = false;

  // initState 初始化注入仓储或启动默认 SQLite 仓储加载。
  @override
  void initState() {
    super.initState();
    final repository = widget.repository;
    if (repository != null) {
      _useRepository(repository);
      _isLoading = false;
      return;
    }
    _loadRepository();
  }

  // dispose 释放编辑控制器和 SQLite 仓储连接。
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    final repository = _repository;
    if (repository is SqliteNoteRepository) {
      unawaited(repository.close());
    }
    super.dispose();
  }

  // build 构建本地笔记浏览和编辑页面。
  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (_isLoading) {
      return const Scaffold(
        appBar: _NoteAppBar(),
        body: Center(child: Text('正在加载笔记...')),
      );
    }
    if (_loadError != null || repository == null) {
      return Scaffold(
        appBar: const _NoteAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('笔记数据库初始化失败'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadRepository,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final folders = repository.listFolders();
    final selectedFolderId = _selectedFolderId;
    final notes = selectedFolderId == null
        ? <Note>[]
        : repository.listNotes(selectedFolderId);
    final selectedNote = _selectedNoteId == null
        ? null
        : repository.findNote(_selectedNoteId!);

    return Scaffold(
      appBar: const _NoteAppBar(),
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
                Expanded(
                  child: _NoteDetailPane(
                    note: selectedNote,
                    isEditing: _isEditing,
                    isCreating: _isCreating,
                    titleController: _titleController,
                    contentController: _contentController,
                    onCreate: _startCreateNote,
                    onEdit: selectedNote == null
                        ? null
                        : () => _startEditNote(selectedNote),
                    onSave: _saveEditing,
                    onCancel: _cancelEditing,
                  ),
                ),
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
              _NoteDetailPane(
                note: selectedNote,
                isEditing: _isEditing,
                isCreating: _isCreating,
                titleController: _titleController,
                contentController: _contentController,
                onCreate: _startCreateNote,
                onEdit: selectedNote == null
                    ? null
                    : () => _startEditNote(selectedNote),
                onSave: _saveEditing,
                onCancel: _cancelEditing,
              ),
            ],
          );
        },
      ),
    );
  }

  // _loadRepository 异步打开默认笔记仓储。
  Future<void> _loadRepository() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final factory = widget.repositoryFactory ?? SqliteNoteRepository.open;
      final repository = await factory();
      if (!mounted) {
        if (repository is SqliteNoteRepository) {
          unawaited(repository.close());
        }
        return;
      }
      setState(() {
        _useRepository(repository);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  // _useRepository 设置当前仓储并选择默认文件夹和笔记。
  void _useRepository(NoteRepository repository) {
    _repository = repository;
    final folders = repository.listFolders();
    if (folders.isEmpty) {
      _selectedFolderId = null;
      _selectedNoteId = null;
      return;
    }
    _selectFolder(folders.first.id, updateState: false);
  }

  // _selectFolder 切换文件夹并自动选择第一条笔记。
  void _selectFolder(String folderId, {bool updateState = true}) {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    final notes = repository.listNotes(folderId);
    final nextNoteId = notes.isEmpty ? null : notes.first.id;

    if (updateState) {
      setState(() {
        _selectedFolderId = folderId;
        _selectedNoteId = nextNoteId;
        _isEditing = false;
        _isCreating = false;
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
      _isEditing = false;
      _isCreating = false;
    });
  }

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
    final repository = _repository;
    if (repository == null) {
      return;
    }

    final title = _normalizeTitle(_titleController.text);
    final content = _contentController.text.trim();

    if (_isCreating) {
      final folderId = _selectedFolderId;
      if (folderId == null) {
        _cancelEditing();
        return;
      }

      final note = repository.createNote(
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

    final updated = repository.updateNote(
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
}

// _NoteAppBar 提供笔记页面标题栏。
class _NoteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NoteAppBar();

  // preferredSize 返回标准应用栏高度。
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  // build 构建标题栏。
  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('轻量同步笔记'));
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
                TextButton(onPressed: onCancel, child: const Text('取消')),
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

// _normalizeTitle 规范化标题，避免保存空标题。
String _normalizeTitle(String value) {
  final title = value.trim();
  return title.isEmpty ? '未命名笔记' : title;
}

// _formatUpdatedAt 格式化笔记更新时间。
String _formatUpdatedAt(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
