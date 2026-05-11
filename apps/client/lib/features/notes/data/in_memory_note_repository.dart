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
