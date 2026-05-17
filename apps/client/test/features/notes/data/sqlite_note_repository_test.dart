// 文件说明：测试 SQLite 笔记仓储的种子数据、创建持久化和编辑持久化。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/features/notes/domain/folder.dart';
import 'package:note_client/features/notes/domain/note.dart';
import 'package:note_client/features/notes/data/sqlite_note_repository.dart';

// main 验证 SQLite 仓储持久化行为。
void main() {
  // createTempPath 创建每个测试独立使用的临时数据库路径。
  Future<String> createTempPath() async {
    final directory = await Directory.systemTemp.createTemp(
      'note_sqlite_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    return '${directory.path}${Platform.pathSeparator}notes.db';
  }

  test('首次打开会写入种子文件夹和种子笔记', () async {
    final repository = await SqliteNoteRepository.openForPath(
      await createTempPath(),
    );
    addTearDown(repository.close);

    final folders = repository.listFolders();
    final notes = repository.listNotes('folder-inbox');

    expect(folders.map((folder) => folder.name), contains('收集箱'));
    expect(notes.map((note) => note.title), contains('欢迎使用轻量同步笔记'));
  });

  test('新建笔记后重新打开数据库仍能读取', () async {
    final databasePath = await createTempPath();
    final first = await SqliteNoteRepository.openForPath(databasePath);
    final created = first.createNote(
      folderId: 'folder-inbox',
      title: '持久化测试',
      content: '这条笔记需要在重启后保留。',
    );
    await first.close();

    final second = await SqliteNoteRepository.openForPath(databasePath);
    addTearDown(second.close);

    expect(second.findNote(created.id)?.title, '持久化测试');
    expect(second.findNote(created.id)?.content, '这条笔记需要在重启后保留。');
  });

  test('编辑笔记后重新打开数据库仍能读取最新内容', () async {
    final databasePath = await createTempPath();
    final first = await SqliteNoteRepository.openForPath(databasePath);
    final created = first.createNote(
      folderId: 'folder-work',
      title: '旧标题',
      content: '旧正文',
    );
    final updated = first.updateNote(
      noteId: created.id,
      title: '新标题',
      content: '新正文',
    );
    await first.close();

    final second = await SqliteNoteRepository.openForPath(databasePath);
    addTearDown(second.close);

    expect(updated?.id, created.id);
    expect(second.findNote(created.id)?.title, '新标题');
    expect(second.findNote(created.id)?.content, '新正文');
  });

  test('listAllNotes 返回所有文件夹下的笔记', () async {
    final repository = await SqliteNoteRepository.openForPath(
      await createTempPath(),
    );
    addTearDown(repository.close);

    final notes = repository.listAllNotes();

    expect(notes.map((note) => note.id), contains('note-welcome'));
    expect(notes.map((note) => note.id), contains('note-work-plan'));
  });

  test('upsertFolder 和 upsertNote 会新增或覆盖本地数据', () async {
    final databasePath = await createTempPath();
    final first = await SqliteNoteRepository.openForPath(databasePath);
    first.upsertFolder(const Folder(id: 'folder-remote', name: '远端文件夹'));
    first.upsertNote(
      Note(
        id: 'note-remote',
        folderId: 'folder-remote',
        title: '远端标题',
        content: '远端正文',
        updatedAt: DateTime(2026, 5, 17, 11, 0),
      ),
    );
    first.upsertNote(
      Note(
        id: 'note-remote',
        folderId: 'folder-remote',
        title: '远端标题更新',
        content: '远端正文更新',
        updatedAt: DateTime(2026, 5, 17, 11, 5),
      ),
    );
    await first.close();

    final second = await SqliteNoteRepository.openForPath(databasePath);
    addTearDown(second.close);

    expect(
      second.listFolders().map((folder) => folder.name),
      contains('远端文件夹'),
    );
    expect(second.findNote('note-remote')?.title, '远端标题更新');
    expect(second.findNote('note-remote')?.content, '远端正文更新');
  });
}
