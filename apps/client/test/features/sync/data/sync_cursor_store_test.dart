// 文件说明：测试同步游标本地存储。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/features/sync/data/sync_cursor_store.dart';

// main 验证同步游标存储行为。
void main() {
  // createTempFile 创建每个测试独立使用的游标文件路径。
  Future<File> createTempFile() async {
    final directory = await Directory.systemTemp.createTemp(
      'note_sync_cursor_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    return File('${directory.path}${Platform.pathSeparator}cursor.json');
  }

  test('FileSyncCursorStore 文件不存在时返回 0', () async {
    final store = FileSyncCursorStore(file: await createTempFile());

    expect(await store.load(), 0);
  });

  test('FileSyncCursorStore 可以保存、读取和清除游标', () async {
    final store = FileSyncCursorStore(file: await createTempFile());

    await store.save(12);
    expect(await store.load(), 12);

    await store.clear();
    expect(await store.load(), 0);
  });

  test('MemorySyncCursorStore 可以保存和读取游标', () async {
    final store = MemorySyncCursorStore(initialVersion: 3);

    expect(await store.load(), 3);
    await store.save(9);
    expect(await store.load(), 9);
  });
}
