// 文件说明：本地笔记浏览、编辑和默认 SQLite 仓储初始化页面。
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/note_repository.dart';
import '../data/sqlite_note_repository.dart';
import '../domain/folder.dart';
import '../domain/note.dart';
import 'markdown_note_body.dart';

const _calmBg = Color(0xFFEEF8FB);
const _calmPanel = Color(0xFFFFFFFF);
const _calmPanelSoft = Color(0xFFF8FBFC);
const _calmLine = Color(0xFFD9E7EC);
const _calmLineStrong = Color(0xFFB9D2DB);
const _calmText = Color(0xFF103746);
const _calmMuted = Color(0xFF627986);
const _calmFaint = Color(0xFF8AA0AA);
const _calmPrimary = Color(0xFF0891B2);
const _calmPrimaryDark = Color(0xFF0E7490);
const _calmPrimarySoft = Color(0xFFD8F3F8);
const _calmGreen = Color(0xFF059669);

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
        body: _StatusShell(
          icon: Icons.hourglass_empty_rounded,
          title: '正在加载笔记...',
          message: '正在打开本地 SQLite 数据库',
        ),
      );
    }
    if (_loadError != null || repository == null) {
      return Scaffold(
        body: _StatusShell(
          icon: Icons.error_outline_rounded,
          title: '笔记数据库初始化失败',
          message: '请重试打开本地笔记数据库',
          action: FilledButton.icon(
            onPressed: _loadRepository,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
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
    final selectedFolderName = _folderName(folders, selectedFolderId);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (folders.isEmpty) {
              return const _StatusShell(
                icon: Icons.folder_off_outlined,
                title: '暂无文件夹',
                message: '后续会支持创建和管理文件夹',
              );
            }

            final isWide = constraints.maxWidth >= 980;
            return Container(
              color: _calmBg,
              padding: EdgeInsets.all(isWide ? 24 : 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isWide ? 18 : 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _calmPanel,
                    border: Border.all(color: _calmLineStrong),
                    borderRadius: BorderRadius.circular(isWide ? 18 : 14),
                  ),
                  child: Column(
                    children: [
                      _TopToolbar(
                        onCreate: _startCreateNote,
                        showSearch: isWide,
                      ),
                      Expanded(
                        child: isWide
                            ? _WideWorkspace(
                                repository: repository,
                                folders: folders,
                                notes: notes,
                                selectedFolderId: selectedFolderId,
                                selectedFolderName: selectedFolderName,
                                selectedNoteId: _selectedNoteId,
                                selectedNote: selectedNote,
                                isEditing: _isEditing,
                                isCreating: _isCreating,
                                titleController: _titleController,
                                contentController: _contentController,
                                onFolderSelected: _selectFolder,
                                onNoteSelected: _selectNote,
                                onLinkedNoteSelected: _openLinkedNote,
                                onCreate: _startCreateNote,
                                onEdit: selectedNote == null
                                    ? null
                                    : () => _startEditNote(selectedNote),
                                onSave: _saveEditing,
                                onCancel: _cancelEditing,
                              )
                            : _NarrowWorkspace(
                                repository: repository,
                                folders: folders,
                                notes: notes,
                                selectedFolderId: selectedFolderId,
                                selectedFolderName: selectedFolderName,
                                selectedNoteId: _selectedNoteId,
                                selectedNote: selectedNote,
                                isEditing: _isEditing,
                                isCreating: _isCreating,
                                titleController: _titleController,
                                contentController: _contentController,
                                onFolderSelected: _selectFolder,
                                onNoteSelected: _selectNote,
                                onLinkedNoteSelected: _openLinkedNote,
                                onCreate: _startCreateNote,
                                onEdit: selectedNote == null
                                    ? null
                                    : () => _startEditNote(selectedNote),
                                onSave: _saveEditing,
                                onCancel: _cancelEditing,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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

  // _openLinkedNote 切换到内部链接指向的文件夹和笔记。
  void _openLinkedNote(Note note) {
    setState(() {
      _selectedFolderId = note.folderId;
      _selectedNoteId = note.id;
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

// _TopToolbar 展示产品品牌、搜索占位和主操作。
class _TopToolbar extends StatelessWidget {
  const _TopToolbar({required this.onCreate, required this.showSearch});

  final VoidCallback onCreate;
  final bool showSearch;

  // build 构建顶部工具栏。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: _calmPanel,
        border: Border(bottom: BorderSide(color: _calmLine)),
      ),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 12),
          const Text(
            '轻量同步笔记',
            style: TextStyle(
              color: _calmText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (showSearch) ...[const _SearchBox(), const SizedBox(width: 12)],
          const _SyncBadge(),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建'),
          ),
        ],
      ),
    );
  }
}

// _BrandMark 展示产品识别图形。
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  // build 构建品牌方形标识。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _calmPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'N',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

// _SearchBox 展示后续搜索能力的稳定位置。
class _SearchBox extends StatelessWidget {
  const _SearchBox();

  // build 构建搜索占位框。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _calmPanelSoft,
        border: Border.all(color: _calmLine),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: _calmFaint),
          SizedBox(width: 8),
          Text(
            '搜索标题、正文或链接...',
            style: TextStyle(color: _calmFaint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// _SyncBadge 展示本地保存状态。
class _SyncBadge extends StatelessWidget {
  const _SyncBadge();

  // build 构建 SQLite 状态徽标。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF3),
        border: Border.all(color: const Color(0xFFBFEBD8)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: _calmGreen),
          SizedBox(width: 6),
          Text(
            'SQLite 已保存',
            style: TextStyle(
              color: Color(0xFF047857),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// _WideWorkspace 展示 Windows 宽屏三栏工作区。
class _WideWorkspace extends StatelessWidget {
  const _WideWorkspace({
    required this.repository,
    required this.folders,
    required this.notes,
    required this.selectedFolderId,
    required this.selectedFolderName,
    required this.selectedNoteId,
    required this.selectedNote,
    required this.isEditing,
    required this.isCreating,
    required this.titleController,
    required this.contentController,
    required this.onFolderSelected,
    required this.onNoteSelected,
    required this.onLinkedNoteSelected,
    required this.onCreate,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
  });

  final NoteRepository repository;
  final List<Folder> folders;
  final List<Note> notes;
  final String? selectedFolderId;
  final String selectedFolderName;
  final String? selectedNoteId;
  final Note? selectedNote;
  final bool isEditing;
  final bool isCreating;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final ValueChanged<String> onFolderSelected;
  final ValueChanged<String> onNoteSelected;
  final ValueChanged<Note> onLinkedNoteSelected;
  final VoidCallback onCreate;
  final VoidCallback? onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  // build 构建宽屏三栏布局。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FolderPane(
          folders: folders,
          selectedFolderId: selectedFolderId,
          onFolderSelected: onFolderSelected,
        ),
        _NoteListPane(
          notes: notes,
          selectedFolderName: selectedFolderName,
          selectedNoteId: selectedNoteId,
          onNoteSelected: onNoteSelected,
        ),
        Expanded(
          child: _NoteDetailPane(
            repository: repository,
            note: selectedNote,
            folderName: selectedFolderName,
            isEditing: isEditing,
            isCreating: isCreating,
            titleController: titleController,
            contentController: contentController,
            onCreate: onCreate,
            onLinkedNoteSelected: onLinkedNoteSelected,
            onEdit: onEdit,
            onSave: onSave,
            onCancel: onCancel,
          ),
        ),
      ],
    );
  }
}

// _NarrowWorkspace 展示 Android 和窄屏单列工作区。
class _NarrowWorkspace extends StatelessWidget {
  const _NarrowWorkspace({
    required this.repository,
    required this.folders,
    required this.notes,
    required this.selectedFolderId,
    required this.selectedFolderName,
    required this.selectedNoteId,
    required this.selectedNote,
    required this.isEditing,
    required this.isCreating,
    required this.titleController,
    required this.contentController,
    required this.onFolderSelected,
    required this.onNoteSelected,
    required this.onLinkedNoteSelected,
    required this.onCreate,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
  });

  final NoteRepository repository;
  final List<Folder> folders;
  final List<Note> notes;
  final String? selectedFolderId;
  final String selectedFolderName;
  final String? selectedNoteId;
  final Note? selectedNote;
  final bool isEditing;
  final bool isCreating;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final ValueChanged<String> onFolderSelected;
  final ValueChanged<String> onNoteSelected;
  final ValueChanged<Note> onLinkedNoteSelected;
  final VoidCallback onCreate;
  final VoidCallback? onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  // build 构建窄屏单列布局。
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _FolderStrip(
          folders: folders,
          selectedFolderId: selectedFolderId,
          onFolderSelected: onFolderSelected,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: _NoteListPane(
            notes: notes,
            selectedFolderName: selectedFolderName,
            selectedNoteId: selectedNoteId,
            onNoteSelected: onNoteSelected,
            compact: true,
          ),
        ),
        const SizedBox(height: 12),
        _NoteDetailPane(
          repository: repository,
          note: selectedNote,
          folderName: selectedFolderName,
          isEditing: isEditing,
          isCreating: isCreating,
          titleController: titleController,
          contentController: contentController,
          onCreate: onCreate,
          onLinkedNoteSelected: onLinkedNoteSelected,
          onEdit: onEdit,
          onSave: onSave,
          onCancel: onCancel,
          compact: true,
        ),
      ],
    );
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
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: Color(0xFFF5FBFD),
        border: Border(right: BorderSide(color: _calmLine)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        children: [
          const _SectionLabel('Folders'),
          for (final folder in folders)
            _FolderTile(
              folder: folder,
              selected: folder.id == selectedFolderId,
              onTap: () => onFolderSelected(folder.id),
            ),
          const _SectionLabel('System'),
          const _SystemTile(icon: Icons.schedule_rounded, label: '最近编辑'),
          const _SystemTile(icon: Icons.cloud_done_outlined, label: '未同步'),
          const SizedBox(height: 16),
          const _LocalSaveCard(),
        ],
      ),
    );
  }
}

// _FolderTile 展示单个文件夹入口。
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.selected,
    required this.onTap,
  });

  final Folder folder;
  final bool selected;
  final VoidCallback onTap;

  // build 构建文件夹选择块。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: selected ? _calmLine : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: selected ? _calmPrimary : _calmMuted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _calmPrimaryDark : _calmText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  ' ',
                  style: TextStyle(color: _calmFaint, fontSize: 12),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _SystemTile 展示系统视图入口占位。
class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  // build 构建系统入口。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: _calmMuted),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              color: _calmMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// _LocalSaveCard 展示本地保存状态说明。
class _LocalSaveCard extends StatelessWidget {
  const _LocalSaveCard();

  // build 构建本地保存说明卡。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _calmLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: _calmGreen),
              SizedBox(width: 6),
              Text(
                'SQLite 已保存',
                style: TextStyle(
                  color: _calmText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '当前文件夹和笔记已保存到本地。同步账号接入后，这里显示设备状态。',
            style: TextStyle(color: _calmMuted, fontSize: 12, height: 1.45),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final folder in folders) ...[
            ChoiceChip(
              label: Text(folder.name),
              selected: folder.id == selectedFolderId,
              onSelected: (_) => onFolderSelected(folder.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// _NoteListPane 展示当前文件夹下的笔记列表。
class _NoteListPane extends StatelessWidget {
  const _NoteListPane({
    required this.notes,
    required this.selectedFolderName,
    required this.selectedNoteId,
    required this.onNoteSelected,
    this.compact = false,
  });

  final List<Note> notes;
  final String selectedFolderName;
  final String? selectedNoteId;
  final ValueChanged<String> onNoteSelected;
  final bool compact;

  // build 构建笔记列表或空状态。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 344,
      decoration: BoxDecoration(
        color: _calmPanelSoft,
        border: Border(
          right: compact ? BorderSide.none : const BorderSide(color: _calmLine),
        ),
      ),
      child: Column(
        children: [
          _NoteListHeader(folderName: selectedFolderName),
          Expanded(
            child: notes.isEmpty
                ? const _EmptyState(message: '暂无笔记')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _NoteCard(
                        note: note,
                        selected: note.id == selectedNoteId,
                        onTap: () => onNoteSelected(note.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// _NoteListHeader 展示笔记列表标题和筛选入口。
class _NoteListHeader extends StatelessWidget {
  const _NoteListHeader({required this.folderName});

  final String folderName;

  // build 构建列表头部。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _calmLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  folderName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _calmText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('排序')),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: '全部', selected: true),
              _FilterChip(label: '含链接'),
              _FilterChip(label: '今天'),
            ],
          ),
        ],
      ),
    );
  }
}

// _FilterChip 展示列表筛选状态。
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  // build 构建筛选胶囊。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _calmPrimarySoft : Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFFA7DCE8) : _calmLine,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _calmPrimaryDark : _calmMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// _NoteCard 展示笔记列表项。
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  // build 构建笔记信息卡。
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? _calmLineStrong : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _calmText,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _calmMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _formatUpdatedAt(note.updatedAt),
                    style: const TextStyle(
                      color: _calmFaint,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _calmGreen,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _NoteDetailPane 展示笔记详情或编辑表单。
class _NoteDetailPane extends StatelessWidget {
  const _NoteDetailPane({
    required this.repository,
    required this.note,
    required this.folderName,
    required this.isEditing,
    required this.isCreating,
    required this.titleController,
    required this.contentController,
    required this.onCreate,
    required this.onLinkedNoteSelected,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    this.compact = false,
  });

  final NoteRepository repository;
  final Note? note;
  final String folderName;
  final bool isEditing;
  final bool isCreating;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final VoidCallback onCreate;
  final ValueChanged<Note> onLinkedNoteSelected;
  final VoidCallback? onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool compact;

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
        compact: compact,
      );
    }

    final note = this.note;
    if (note == null) {
      return _EmptyDetailPane(onCreate: onCreate);
    }

    final detailBody = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 60,
        vertical: compact ? 22 : 44,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Note',
              style: TextStyle(
                color: _calmPrimaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              note.title,
              style: TextStyle(
                color: const Color(0xFF092F3C),
                fontSize: compact ? 26 : 36,
                height: 1.16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '更新于 ${_formatUpdatedAt(note.updatedAt)} · SQLite 已保存',
              style: const TextStyle(color: _calmFaint, fontSize: 13),
            ),
            const SizedBox(height: 30),
            MarkdownNoteBody(
              content: note.content,
              repository: repository,
              onNoteSelected: onLinkedNoteSelected,
            ),
          ],
        ),
      ),
    );

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _DocumentToolbar(
            folderName: folderName,
            onCreate: onCreate,
            onEdit: onEdit,
            compact: compact,
          ),
          if (compact) detailBody else Flexible(child: detailBody),
        ],
      ),
    );
  }
}

// _DocumentToolbar 展示详情区路径和操作。
class _DocumentToolbar extends StatelessWidget {
  const _DocumentToolbar({
    required this.folderName,
    required this.onCreate,
    required this.onEdit,
    required this.compact,
  });

  final String folderName;
  final VoidCallback onCreate;
  final VoidCallback? onEdit;
  final bool compact;

  // build 构建文档工具栏。
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _calmLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$folderName / 当前笔记',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _calmMuted, fontSize: 13),
            ),
          ),
          if (!compact)
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.link_rounded),
              label: const Text('复制链接'),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建'),
          ),
        ],
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
    required this.compact,
  });

  final bool isCreating;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool compact;

  // build 构建编辑表单和操作按钮。
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 60,
          vertical: compact ? 22 : 44,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCreating ? '新建笔记' : '编辑笔记',
                style: TextStyle(
                  color: _calmText,
                  fontSize: compact ? 22 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '标题'),
                style: TextStyle(
                  color: _calmText,
                  fontSize: compact ? 20 : 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: '正文',
                  alignLabelWithHint: true,
                ),
                minLines: compact ? 7 : 10,
                maxLines: 18,
                style: const TextStyle(
                  color: Color(0xFF234755),
                  fontSize: 15,
                  height: 1.75,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('取消')),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
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
    return _StatusShell(
      icon: Icons.note_add_outlined,
      title: '暂无笔记',
      message: '在当前文件夹中新建第一条笔记',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建'),
      ),
      embedded: true,
    );
  }
}

// _StatusShell 展示加载、错误和空状态。
class _StatusShell extends StatelessWidget {
  const _StatusShell({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.embedded = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool embedded;

  // build 构建居中状态面板。
  @override
  Widget build(BuildContext context) {
    return Container(
      color: embedded ? Colors.white : _calmBg,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _calmLine),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _calmPrimary, size: 32),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _calmText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _calmMuted, fontSize: 13),
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
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
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: _calmMuted, fontSize: 14),
      ),
    );
  }
}

// _SectionLabel 展示侧边栏分组标题。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  // build 构建分组标题。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: _calmFaint,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// _folderName 返回当前选中文件夹名称。
String _folderName(List<Folder> folders, String? folderId) {
  for (final folder in folders) {
    if (folder.id == folderId) {
      return folder.name;
    }
  }
  return folders.isEmpty ? '' : folders.first.name;
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
