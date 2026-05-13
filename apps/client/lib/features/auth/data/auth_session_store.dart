// 文件说明：提供认证会话的内存存储和本地文件存储。
import 'dart:convert';
import 'dart:io';

import '../domain/auth_session.dart';

// AuthSessionStore 定义认证会话读写能力。
abstract interface class AuthSessionStore {
  // load 读取本地认证会话，未登录时返回 null。
  Future<AuthSession?> load();

  // save 保存认证会话。
  Future<void> save(AuthSession session);

  // clear 清除认证会话。
  Future<void> clear();
}

// MemoryAuthSessionStore 提供测试用内存会话存储。
class MemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;

  // load 返回当前内存会话。
  @override
  Future<AuthSession?> load() async => _session;

  // save 保存会话到内存。
  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  // clear 清除内存会话。
  @override
  Future<void> clear() async {
    _session = null;
  }
}

// FileAuthSessionStore 将认证会话保存为 UTF-8 JSON 文件。
class FileAuthSessionStore implements AuthSessionStore {
  FileAuthSessionStore({File? file}) : _file = file ?? File(_defaultPath());

  final File _file;

  // load 从文件读取认证会话，文件缺失或损坏时返回 null。
  @override
  Future<AuthSession?> load() async {
    if (!await _file.exists()) {
      return null;
    }

    try {
      final content = await _file.readAsString(encoding: utf8);
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, Object?>) {
        await clear();
        return null;
      }
      return AuthSession.fromJson(decoded);
    } on FormatException {
      await clear();
      return null;
    } on IOException {
      return null;
    }
  }

  // save 将认证会话写入本地文件。
  @override
  Future<void> save(AuthSession session) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode(session.toJson()),
      encoding: utf8,
      flush: true,
    );
  }

  // clear 删除本地认证会话文件。
  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  // _defaultPath 返回运行平台默认会话文件路径。
  static String _defaultPath() {
    final base =
        Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    return '$base${Platform.pathSeparator}note_client${Platform.pathSeparator}auth_session.json';
  }
}
