// 文件说明：提供基于 SQLite 的本地笔记仓储实现。
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../domain/folder.dart';
import '../domain/note.dart';
import 'note_repository.dart';

// SqliteNoteRepository 使用 SQLite 保存文件夹和笔记数据。
class SqliteNoteRepository implements NoteRepository {
  SqliteNoteRepository._(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _databaseName = 'note_client.db';
  final Database _database;
  final DateTime Function() _now;

  // open 打开默认位置的 SQLite 数据库。
  static Future<SqliteNoteRepository> open({DateTime Function()? now}) async {
    final appData = Platform.environment['APPDATA'];
    final databaseDirectory = appData == null || appData.isEmpty
        ? path.join(Directory.current.path, 'data')
        : path.join(appData, 'NoteClient');
    final databasePath = path.join(databaseDirectory, _databaseName);
    return openForPath(databasePath, now: now);
  }

  // openForPath 打开指定路径的 SQLite 数据库，主要用于测试和可控启动。
  static Future<SqliteNoteRepository> openForPath(
    String databasePath, {
    DateTime Function()? now,
  }) async {
    final parent = Directory(path.dirname(databasePath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final database = sqlite3.open(databasePath);
    final repository = SqliteNoteRepository._(database, now: now);
    repository._createSchema();
    repository._seedIfNeeded();
    return repository;
  }

  // close 关闭 SQLite 数据库连接。
  Future<void> close() async {
    _database.close();
  }

  // listFolders 返回本地文件夹列表。
  @override
  List<Folder> listFolders() {
    final rows = _database.select(
      'SELECT id, name FROM folders ORDER BY created_at ASC',
    );
    return [
      for (final row in rows)
        Folder(id: row['id'] as String, name: row['name'] as String),
    ];
  }

  // listNotes 返回指定文件夹下按更新时间倒序排列的笔记。
  @override
  List<Note> listNotes(String folderId) {
    final rows = _database.select(
      '''
SELECT id, folder_id, title, content, updated_at
FROM notes
WHERE folder_id = ?
ORDER BY updated_at DESC
''',
      [folderId],
    );
    return [for (final row in rows) _noteFromRow(row)];
  }

  // findNote 根据笔记 ID 返回匹配笔记。
  @override
  Note? findNote(String noteId) {
    final rows = _database.select(
      '''
SELECT id, folder_id, title, content, updated_at
FROM notes
WHERE id = ?
LIMIT 1
''',
      [noteId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _noteFromRow(rows.first);
  }

  // createNote 在指定文件夹下创建并保存笔记。
  @override
  Note createNote({
    required String folderId,
    required String title,
    required String content,
  }) {
    final now = _now();
    final note = Note(
      id: 'note-local-${now.microsecondsSinceEpoch}',
      folderId: folderId,
      title: title,
      content: content,
      updatedAt: now,
    );
    _database.execute(
      '''
INSERT INTO notes (id, folder_id, title, content, updated_at)
VALUES (?, ?, ?, ?, ?)
''',
      [
        note.id,
        note.folderId,
        note.title,
        note.content,
        note.updatedAt.toIso8601String(),
      ],
    );
    return note;
  }

  // updateNote 更新已有笔记。
  @override
  Note? updateNote({
    required String noteId,
    required String title,
    required String content,
  }) {
    final previous = findNote(noteId);
    if (previous == null) {
      return null;
    }

    final updated = Note(
      id: previous.id,
      folderId: previous.folderId,
      title: title,
      content: content,
      updatedAt: _now(),
    );
    _database.execute(
      '''
UPDATE notes
SET title = ?, content = ?, updated_at = ?
WHERE id = ?
''',
      [
        updated.title,
        updated.content,
        updated.updatedAt.toIso8601String(),
        noteId,
      ],
    );
    return updated;
  }

  // _createSchema 创建第一版本地笔记数据库表。
  void _createSchema() {
    _database.execute('''
CREATE TABLE IF NOT EXISTS folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
    _database.execute('''
CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  folder_id TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    _database.execute('''
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
  }

  // _seedIfNeeded 首次打开数据库时写入默认文件夹和笔记。
  void _seedIfNeeded() {
    final seeded = _database.select(
      'SELECT value FROM meta WHERE key = ? LIMIT 1',
      ['seeded'],
    );
    if (seeded.isNotEmpty) {
      return;
    }

    _database.execute('BEGIN TRANSACTION');
    try {
      for (final folder in _seedFolders) {
        _database.execute(
          '''
INSERT INTO folders (id, name, created_at)
VALUES (?, ?, ?)
''',
          [folder.id, folder.name, DateTime(2026, 5, 11).toIso8601String()],
        );
      }
      for (final note in _seedNotes) {
        _database.execute(
          '''
INSERT INTO notes (id, folder_id, title, content, updated_at)
VALUES (?, ?, ?, ?, ?)
''',
          [
            note.id,
            note.folderId,
            note.title,
            note.content,
            note.updatedAt.toIso8601String(),
          ],
        );
      }
      _database.execute('INSERT INTO meta (key, value) VALUES (?, ?)', [
        'seeded',
        'true',
      ]);
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  // _noteFromRow 将 SQLite 查询结果转换为笔记领域对象。
  Note _noteFromRow(Row row) {
    return Note(
      id: row['id'] as String,
      folderId: row['folder_id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

const _seedFolders = [
  Folder(id: 'folder-inbox', name: '收集箱'),
  Folder(id: 'folder-work', name: '工作'),
  Folder(id: 'folder-life', name: '生活'),
];

final _seedNotes = [
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
