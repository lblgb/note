// 文件说明：提供同步服务端版本游标的本地存储能力。
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

// SyncCursorStore 定义同步游标读写能力。
abstract interface class SyncCursorStore {
  // load 读取本地保存的服务端版本游标。
  Future<int> load();

  // save 保存本地服务端版本游标。
  Future<void> save(int version);

  // clear 清除本地服务端版本游标。
  Future<void> clear();
}

// FileSyncCursorStore 使用 JSON 文件保存同步游标。
class FileSyncCursorStore implements SyncCursorStore {
  FileSyncCursorStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;

  // load 读取文件中的同步游标，缺失或损坏时返回 0。
  @override
  Future<int> load() async {
    if (!await _file.exists()) {
      return 0;
    }
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is Map<String, Object?>) {
        return (decoded['serverVersion'] as num?)?.toInt() ?? 0;
      }
    } on FormatException {
      await clear();
    }
    return 0;
  }

  // save 保存同步游标到文件。
  @override
  Future<void> save(int version) async {
    final parent = _file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await _file.writeAsString(jsonEncode({'serverVersion': version}));
  }

  // clear 删除同步游标文件。
  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

// MemorySyncCursorStore 提供测试用内存同步游标存储。
class MemorySyncCursorStore implements SyncCursorStore {
  MemorySyncCursorStore({int initialVersion = 0}) : _version = initialVersion;

  int _version;

  // load 读取内存游标。
  @override
  Future<int> load() async => _version;

  // save 保存内存游标。
  @override
  Future<void> save(int version) async {
    _version = version;
  }

  // clear 清除内存游标。
  @override
  Future<void> clear() async {
    _version = 0;
  }
}

// _defaultFile 返回默认同步游标文件路径。
File _defaultFile() {
  final appData = Platform.environment['APPDATA'];
  final directory = appData == null || appData.isEmpty
      ? path.join(Directory.current.path, 'data')
      : path.join(appData, 'NoteClient');
  return File(path.join(directory, 'sync_cursor.json'));
}
