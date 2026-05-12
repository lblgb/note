// 文件说明：测试 SQLite 笔记仓储的种子数据、创建持久化和编辑持久化。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
