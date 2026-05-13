// 文件说明：测试认证会话本地存储的保存、读取、清除和容错行为。
import 'dart:io';

import 'package:note_client/features/auth/data/auth_session_store.dart';
import 'package:note_client/features/auth/domain/auth_session.dart';
import 'package:test/test.dart';

// main 验证认证会话存储实现。
void main() {
  // createTempFile 为每个用例创建独立临时会话文件。
  Future<File> createTempFile() async {
    final directory = await Directory.systemTemp.createTemp(
      'note_auth_session_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    return File('${directory.path}${Platform.pathSeparator}auth_session.json');
  }

  const session = AuthSession(
    user: AuthUser(id: 'usr_1', email: 'user@example.com', displayName: '用户'),
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  test('FileAuthSessionStore 可以保存并读取会话', () async {
    final store = FileAuthSessionStore(file: await createTempFile());

    await store.save(session);
    final loaded = await store.load();

    expect(loaded?.user.email, 'user@example.com');
    expect(loaded?.accessToken, 'access-token');
    expect(loaded?.refreshToken, 'refresh-token');
  });

  test('FileAuthSessionStore 文件不存在时返回 null', () async {
    final store = FileAuthSessionStore(file: await createTempFile());

    expect(await store.load(), isNull);
  });

  test('FileAuthSessionStore clear 会删除本地会话', () async {
    final store = FileAuthSessionStore(file: await createTempFile());

    await store.save(session);
    await store.clear();

    expect(await store.load(), isNull);
  });

  test('FileAuthSessionStore 遇到损坏 JSON 时返回 null 并删除文件', () async {
    final file = await createTempFile();
    await file.create(recursive: true);
    await file.writeAsString('{broken json');
    final store = FileAuthSessionStore(file: file);

    expect(await store.load(), isNull);
    expect(await file.exists(), isFalse);
  });

  test('MemoryAuthSessionStore 可以在测试中保存和清除会话', () async {
    final store = MemoryAuthSessionStore();

    await store.save(session);
    expect((await store.load())?.user.id, 'usr_1');

    await store.clear();
    expect(await store.load(), isNull);
  });
}
