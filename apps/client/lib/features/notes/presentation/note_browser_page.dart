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
    final selectedNote = _selectedNoteId == null
        ? null
        : widget.repository.findNote(_selectedNoteId!);

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
